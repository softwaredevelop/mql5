//+------------------------------------------------------------------+
//|                                                      MFI_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.00" // Enterprise Edition: MTF Fast-Path, 14 MA Signal Line & Volume Routing
#property description "Institutional Money Flow Index (MFI) Suite with 14 MA Types, MTF Fast-Path, and Heikin Ashi."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_minimum 0.0
#property indicator_maximum 100.0
#property indicator_level1  20.0
#property indicator_level2  50.0
#property indicator_level3  80.0
#property indicator_levelcolor clrDarkGray
#property indicator_levelstyle STYLE_DOT

//--- Plot Declarations ---
#property indicator_label1  "MFI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "Signal MA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Included Engines & Core Tools ---
#include <MyIncludes\MFI_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Display Mode Enum
enum ENUM_MFI_DISPLAY_MODE
  {
   DISPLAY_MFI_ONLY,         // MFI Line Only
   DISPLAY_MFI_AND_SIGNAL    // MFI + Signal Moving Average
  };

//--- Input Parameters ---
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;         // Calculation Timeframe (Current or HTF)

input group "=== MFI Core Settings ==="
input int                       InpPeriodMFI      = 14;                     // MFI Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_TYPICAL_STD;      // Price Source (Standard / HA)
input ENUM_MFI_DISPLAY_MODE     InpDisplayMode    = DISPLAY_MFI_AND_SIGNAL; // Display Layers

input group "=== Signal Line Settings ==="
input int                       InpSignalPeriod   = 9;                      // Signal MA Period
input ENUM_MA_TYPE              InpSignalMAType   = EMA;                    // Signal MA Algorithm (14 Pluggable Models)

input group "=== Visual Settings - MFI Line ==="
input color                     InpColorMFI       = clrDodgerBlue;          // MFI Line Color
input ENUM_LINE_STYLE           InpStyleMFI       = STYLE_SOLID;            // MFI Line Style
input int                       InpWidthMFI       = 2;                      // MFI Line Width

input group "=== Visual Settings - Signal Line ==="
input color                     InpColorSignal    = clrOrangeRed;           // Signal Line Color
input ENUM_LINE_STYLE           InpStyleSignal    = STYLE_DOT;              // Signal Line Style
input int                       InpWidthSignal    = 1;                      // Signal Line Width

//--- Indicator Output Buffers ---
double BufferMFI[];
double BufferSignal[];

//--- Internal HTF Data Caches (Chronological Arrays) ---
double   h_open[], h_high[], h_low[], h_close[];
double   h_vol[];
double   h_res_mfi[], h_res_signal[];
datetime h_time[];

//--- Global Objects & State Management ---
CMFICalculator  *g_calculator     = NULL;
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

// 1. Timeframe Resolution & Integrity Guard
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
   SetIndexBuffer(0, BufferMFI,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferMFI,    false);
   ArraySetAsSeries(BufferSignal, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorMFI);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleMFI);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthMFI);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorSignal);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleSignal);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthSignal);

// 4. Visibility Control based on Display Mode
   if(InpDisplayMode == DISPLAY_MFI_ONLY)
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
   else
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);

   int signal_draw_begin = InpPeriodMFI + InpSignalPeriod - 1;
   if(g_is_mtf_mode)
      signal_draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_is_mtf_mode ? 0 : InpPeriodMFI);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, signal_draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

// 5. Initialize Core Calculator Engine
   g_calculator = new CMFICalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriodMFI, InpSignalPeriod, InpSignalMAType, InpSourcePrice))
     {
      Print("Critical Error: Failed to initialize MFI Calculator Engine.");
      return INIT_FAILED;
     }

   string ha_tag  = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str  = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("MFI Pro%s%s(%d, %s %d)",
                                    ha_tag, tf_str, InpPeriodMFI, EnumToString(InpSignalMAType), InpSignalPeriod);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, StringFormat("MFI(%d)", InpPeriodMFI));
   PlotIndexSetString(1, PLOT_LABEL, StringFormat("Signal(%d)", InpSignalPeriod));

// 6. Background MTF Sync Daemon
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
   int warmup = InpPeriodMFI + InpSignalPeriod + 5;
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
                                BufferMFI, BufferSignal);
      else
         g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, tick_volume,
                                BufferMFI, BufferSignal);

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars_mtf = InpPeriodMFI + InpSignalPeriod + 10;
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars_mtf))
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
      if(htf_bars < required_bars_mtf)
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
         ArrayResize(h_res_mfi,    g_htf_count, 2048);
         ArrayResize(h_res_signal, g_htf_count, 2048);

         ArraySetAsSeries(h_time,       false);
         ArraySetAsSeries(h_open,       false);
         ArraySetAsSeries(h_high,       false);
         ArraySetAsSeries(h_low,        false);
         ArraySetAsSeries(h_close,      false);
         ArraySetAsSeries(h_vol,        false);
         ArraySetAsSeries(h_res_mfi,    false);
         ArraySetAsSeries(h_res_signal, false);
        }

      // Single Atomic Bulk Rates Copy
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

      // Compute HTF MFI on Clean HTF Domain
      g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_vol,
                             h_res_mfi, h_res_signal);
      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufferMFI[i]    = EMPTY_VALUE;
            BufferSignal[i] = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         BufferMFI[i]    = h_res_mfi[htf_ptr];
         BufferSignal[i] = h_res_signal[htf_ptr];
        }

      return rates_total;
     }

   if(!g_data_ready)
      return 0;

// B) LIVE TICK FAST-PATH: Update forming candle strictly in RAM
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars_mtf)
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
                                h_res_mfi, h_res_signal);
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

   double val_mfi    = h_res_mfi[live_idx];
   double val_signal = h_res_signal[live_idx];

   for(int i = start; i < rates_total; i++)
     {
      BufferMFI[i]    = val_mfi;
      BufferSignal[i] = val_signal;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int warmup = InpPeriodMFI + InpSignalPeriod + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, warmup, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
