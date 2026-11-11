//+------------------------------------------------------------------+
//|                                                     MACD_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "6.00" // Enterprise Edition: Two-Pointer MTF Fast-Path, Atomic CopyRates & Precision Integrity
#property description "Gerald Appel's MACD with Two-Pointer Fast-Path MTF, Volume Routing, and 14 MA Models."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Plot 1: MACD Histogram
#property indicator_label1  "Histogram"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: MACD Line
#property indicator_label2  "MACD"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot 3: Signal Line
#property indicator_label3  "Signal"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Included Engines & Core Tools
#include <MyIncludes\MACD_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;    // Calculation Timeframe (Current or HTF)

input group "=== MACD Core Settings ==="
input int                       InpFastPeriod     = 12;                // Fast MA Period
input int                       InpSlowPeriod     = 26;                // Slow MA Period
input int                       InpSignalPeriod   = 9;                 // Signal MA Period
input ENUM_MA_TYPE              InpSourceMAType   = EMA;               // Fast/Slow MA Type (14 Pluggable Models)
input ENUM_MA_TYPE              InpSignalMAType   = EMA;               // Signal Line MA Type (14 Pluggable Models)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;   // Price Source (Standard / HA)

input group "=== Visual Settings - MACD Line ==="
input color                     InpColorMACD      = clrDodgerBlue;     // MACD Line Color
input ENUM_LINE_STYLE           InpStyleMACD      = STYLE_SOLID;       // MACD Line Style
input int                       InpWidthMACD      = 2;                 // MACD Line Width

input group "=== Visual Settings - Signal Line ==="
input color                     InpColorSignal    = clrOrangeRed;      // Signal Line Color
input ENUM_LINE_STYLE           InpStyleSignal    = STYLE_SOLID;       // Signal Line Style
input int                       InpWidthSignal    = 1;                 // Signal Line Width

input group "=== Visual Settings - Histogram ==="
input color                     InpColorHist      = clrSilver;         // Histogram Color
input ENUM_LINE_STYLE           InpStyleHist      = STYLE_SOLID;       // Histogram Style
input int                       InpWidthHist      = 1;                 // Histogram Width

//--- Indicator Output Buffers ---
double BufferMACD_Histogram[];
double BufferMACDLine[];
double BufferSignalLine[];

//--- Internal HTF Data Caches (Chronological Arrays) ---
double   h_open[], h_high[], h_low[], h_close[];
double   h_vol[];
double   h_res_macd[], h_res_signal[], h_res_hist[];
datetime h_time[];

//--- Global Objects & State Management ---
CMACDCalculator *g_calculator     = NULL;
bool             g_is_mtf_mode    = false;
ENUM_TIMEFRAMES  g_calc_timeframe;
bool             g_data_ready     = false;
bool             g_data_synced    = false;
int              g_htf_count      = 0;
datetime         g_last_htf_time  = 0;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready    = false;
   g_data_synced   = false;
   g_htf_count     = 0;
   g_last_htf_time = 0;

// 1. Resolve Timeframe and validate direction
   g_calc_timeframe = InpTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      PrintFormat("Critical Error: Target timeframe (%s) must be >= current timeframe (%s).",
                  EnumToString(g_calc_timeframe), EnumToString(Period()));
      return INIT_PARAMETERS_INCORRECT;
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

// 2. Bind Output Buffers
   SetIndexBuffer(0, BufferMACD_Histogram, INDICATOR_DATA);
   SetIndexBuffer(1, BufferMACDLine,       INDICATOR_DATA);
   SetIndexBuffer(2, BufferSignalLine,     INDICATOR_DATA);

   ArraySetAsSeries(BufferMACD_Histogram, false);
   ArraySetAsSeries(BufferMACDLine,       false);
   ArraySetAsSeries(BufferSignalLine,     false);

   ArrayInitialize(BufferMACD_Histogram, 0.0);
   ArrayInitialize(BufferMACDLine,       EMPTY_VALUE);
   ArrayInitialize(BufferSignalLine,     EMPTY_VALUE);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorHist);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleHist);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthHist);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorMACD);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleMACD);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthMACD);

   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColorSignal);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpStyleSignal);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpWidthSignal);

   int slow_period = MathMax(InpFastPeriod, InpSlowPeriod);
   int signal_draw_begin = slow_period + InpSignalPeriod - 2;
   if(g_is_mtf_mode)
      signal_draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, signal_draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, (g_is_mtf_mode ? 0 : slow_period - 1));
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, signal_draw_begin);

// Precision Integrity: Retain 2 extra digits for sub-pip oscillator accuracy
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 2);

// 4. Initialize Core Calculator Engine
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMACDCalculator_HA();
   else
      g_calculator = new CMACDCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpFastPeriod, InpSlowPeriod, InpSignalPeriod, InpSourceMAType, InpSignalMAType, InpSourcePrice))
     {
      Print("Critical Error: Failed to initialize MACD Calculator.");
      return INIT_FAILED;
     }

   string ha_tag     = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str     = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("MACD Pro%s%s(%d,%d,%d)",
                                    ha_tag, tf_str,
                                    InpFastPeriod, InpSlowPeriod, InpSignalPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

// 5. Initialize Background Synchronization Timer (Only for MTF mode)
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_is_mtf_mode)
      EventKillTimer();

   if(CheckPointer(g_calculator) != POINTER_INVALID && g_calculator != NULL)
     {
      delete g_calculator;
      g_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Custom Indicator Calculation Loop                                |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   int warmup = MathMax(InpFastPeriod, InpSlowPeriod) + InpSignalPeriod;
   if(rates_total < warmup || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Enforce chronological indexing (0 = oldest bar)
   ArraySetAsSeries(time,        false);
   ArraySetAsSeries(open,        false);
   ArraySetAsSeries(high,        false);
   ArraySetAsSeries(low,         false);
   ArraySetAsSeries(close,       false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume,      false);

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(volume_limit > 0)
         g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, volume,
                                BufferMACDLine, BufferSignalLine, BufferMACD_Histogram);
      else
         g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, tick_volume,
                                BufferMACDLine, BufferSignalLine, BufferMACD_Histogram);

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars = warmup + 10;
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars))
     {
      g_data_synced = false;
      return 0;
     }

   g_data_synced = true;

   datetime htf_time_current = iTime(_Symbol, g_calc_timeframe, 0);
   bool htf_updated = (htf_time_current != g_last_htf_time);

// A) HTF Bar Closure / Startup: Perform atomic full history sync once
   if(htf_updated || prev_calculated == 0)
     {
      g_last_htf_time = htf_time_current;

      int htf_bars = iBars(_Symbol, g_calc_timeframe);
      if(htf_bars < required_bars)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 3000);

      // Resize all HTF caching arrays with capacity reservation
      if(ArraySize(h_time) != g_htf_count)
        {
         ArrayResize(h_time,       g_htf_count, 2048);
         ArrayResize(h_open,       g_htf_count, 2048);
         ArrayResize(h_high,       g_htf_count, 2048);
         ArrayResize(h_low,        g_htf_count, 2048);
         ArrayResize(h_close,      g_htf_count, 2048);
         ArrayResize(h_vol,        g_htf_count, 2048);
         ArrayResize(h_res_macd,   g_htf_count, 2048);
         ArrayResize(h_res_signal, g_htf_count, 2048);
         ArrayResize(h_res_hist,   g_htf_count, 2048);

         ArraySetAsSeries(h_time,       false);
         ArraySetAsSeries(h_open,       false);
         ArraySetAsSeries(h_high,       false);
         ArraySetAsSeries(h_low,        false);
         ArraySetAsSeries(h_close,      false);
         ArraySetAsSeries(h_vol,        false);
         ArraySetAsSeries(h_res_macd,   false);
         ArraySetAsSeries(h_res_signal, false);
         ArraySetAsSeries(h_res_hist,   false);
        }

      // Single Atomic Bulk Rates Copy (Loads OHLCV in one nanosecond call!)
      MqlRates htf_bulk_rates[];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, g_htf_count, htf_bulk_rates) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

      for(int i = 0; i < g_htf_count; i++)
        {
         h_time[i]  = htf_bulk_rates[i].time;
         h_open[i]  = htf_bulk_rates[i].open;
         h_high[i]  = htf_bulk_rates[i].high;
         h_low[i]   = htf_bulk_rates[i].low;
         h_close[i] = htf_bulk_rates[i].close;
         h_vol[i]   = (vol_limit > 0 && htf_bulk_rates[i].real_volume > 0) ? (double)htf_bulk_rates[i].real_volume : (double)htf_bulk_rates[i].tick_volume;
        }

      // Compute HTF MACD on Clean HTF Domain
      g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_vol,
                             h_res_macd, h_res_signal, h_res_hist);
      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufferMACD_Histogram[i] = 0.0;
            BufferMACDLine[i]       = EMPTY_VALUE;
            BufferSignalLine[i]     = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         BufferMACD_Histogram[i] = h_res_hist[htf_ptr];
         BufferMACDLine[i]       = h_res_macd[htf_ptr];
         BufferSignalLine[i]     = h_res_signal[htf_ptr];
        }

      return rates_total;
     }

   if(!g_data_ready)
      return 0;

// B) LIVE TICK FAST-PATH: Update forming candle strictly in RAM
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      MqlRates htf_rate[1];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, 1, htf_rate) == 1)
        {
         h_time[live_idx]  = htf_rate[0].time;
         h_open[live_idx]  = htf_rate[0].open;
         h_high[live_idx]  = htf_rate[0].high;
         h_low[live_idx]   = htf_rate[0].low;
         h_close[live_idx] = htf_rate[0].close;

         long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
         h_vol[live_idx] = (vol_limit > 0 && htf_rate[0].real_volume > 0) ? (double)htf_rate[0].real_volume : (double)htf_rate[0].tick_volume;

         // Recompute strictly forming bar in RAM
         g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_vol,
                                h_res_macd, h_res_signal, h_res_hist);
        }
     }

// Binary Search for forming bar block start (Zero iBarShift API calls!)
   int first_bar_of_forming_htf = ArrayBsearch(time, htf_time_current);
   if(first_bar_of_forming_htf < 0)
      first_bar_of_forming_htf = 0;
   if(time[first_bar_of_forming_htf] < htf_time_current && first_bar_of_forming_htf < rates_total - 1)
      first_bar_of_forming_htf++;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

   double val_hist   = h_res_hist[live_idx];
   double val_macd   = h_res_macd[live_idx];
   double val_signal = h_res_signal[live_idx];

   for(int i = start; i < rates_total; i++)
     {
      BufferMACD_Histogram[i] = val_hist;
      BufferMACDLine[i]       = val_macd;
      BufferSignalLine[i]     = val_signal;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int warmup = MathMax(InpFastPeriod, InpSlowPeriod) + InpSignalPeriod;
   int required_bars = warmup + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
