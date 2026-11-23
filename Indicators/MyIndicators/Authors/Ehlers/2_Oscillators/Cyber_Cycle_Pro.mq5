//+------------------------------------------------------------------+
//|                                              Cyber_Cycle_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "4.10" // Enterprise Edition: 3-Digit Harmonic Fibonacci Alpha Resolution
#property description "John Ehlers' Resonant Cyber Cycle with Native MTF Fast-Path and 14 MA Signal Options."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_level1 0.0
#property indicator_levelcolor clrDarkGray
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: Cyber Cycle Line
#property indicator_label1  "Cycle"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Signal Line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_SOLID
#property indicator_width1  1

//--- Included Engines & Core Tools ---
#include <MyIncludes\Cyber_Cycle_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;    // Calculation Timeframe (Current or HTF)

input group "=== Cyber Cycle Settings ==="
input double                    InpAlpha          = 0.062;             // Alpha (Fibo: 0.024, 0.038, 0.050, 0.062, 0.076, 0.088)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_MEDIAN_STD;  // Price Source (Standard / HA)

input group "=== Signal Line Settings ==="
input ENUM_CYBER_SIGNAL_TYPE    InpSignalType     = SIGNAL_DELAY_1BAR; // Signal Type (1-Bar Delay or MA)
input int                       InpSignalPeriod   = 3;                 // Signal MA Period (if MA selected)
input ENUM_MA_TYPE              InpSignalMethod   = SMA;               // Signal MA Algorithm (14 Pluggable Models)

input group "=== Visual Settings - Cycle Line ==="
input color                     InpColorCycle     = clrDodgerBlue;     // Cycle Line Color
input ENUM_LINE_STYLE           InpStyleCycle     = STYLE_SOLID;       // Cycle Line Style
input int                       InpWidthCycle     = 2;                 // Cycle Line Width

input group "=== Visual Settings - Signal Line ==="
input color                     InpColorSignal    = clrOrangeRed;      // Signal Line Color
input ENUM_LINE_STYLE           InpStyleSignal    = STYLE_SOLID;       // Signal Line Style
input int                       InpWidthSignal    = 1;                 // Signal Line Width

//--- Indicator Output Buffers ---
double BufferCycle[];
double BufferSignal[];

//--- Internal HTF Data Caches (Chronological Arrays) ---
double   h_open[], h_high[], h_low[], h_close[];
double   h_vol[];
double   h_res_cycle[], h_res_signal[];
datetime h_time[];

//--- Global Objects & State Management ---
CCyberCycleCalculator *g_calculator     = NULL;
bool                  g_is_mtf_mode     = false;
ENUM_TIMEFRAMES       g_calc_timeframe;
bool                  g_data_ready      = false;
bool                  g_data_synced     = false;
int                   g_htf_count       = 0;
datetime              g_last_htf_time   = 0;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready    = false;
   g_data_synced   = false;
   g_htf_count     = 0;
   g_last_htf_time = 0;

// 1. Timeframe Resolution & Direction Guard
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
   SetIndexBuffer(0, BufferCycle,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferCycle,  false);
   ArraySetAsSeries(BufferSignal, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorCycle);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleCycle);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthCycle);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorSignal);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleSignal);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthSignal);

   int draw_begin = 7;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin + (InpSignalType == SIGNAL_MA ? InpSignalPeriod : 1));

// Retain extra precision for sub-pip cycle amplitudes
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 2);

// 4. Initialize Core Calculator Engine
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CCyberCycleCalculator_HA();
   else
      g_calculator = new CCyberCycleCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpAlpha, InpSignalType, InpSignalPeriod, InpSignalMethod))
     {
      Print("Critical Error: Failed to initialize Cyber Cycle Calculator.");
      return INIT_FAILED;
     }

   string ha_tag  = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str  = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string sig_str = (InpSignalType == SIGNAL_DELAY_1BAR) ? "Delay" : StringFormat("%s(%d)", EnumToString(InpSignalMethod), InpSignalPeriod);

// Formatted with 3 decimal places to display precise harmonic Fibonacci alphas
   string short_name = StringFormat("Cyber Cycle%s%s(α=%.3f, %s)", ha_tag, tf_str, InpAlpha, sig_str);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "Cycle");
   PlotIndexSetString(1, PLOT_LABEL, "Signal");

// 5. Background MTF Sync Daemon
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
   int required_bars = 15;
   if(rates_total < required_bars || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Enforce chronological indexing (0 = oldest bar)
   ArraySetAsSeries(time,        false);
   ArraySetAsSeries(open,        false);
   ArraySetAsSeries(high,        false);
   ArraySetAsSeries(low,         false);
   ArraySetAsSeries(close,       false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume,      false);

// EXACT MATHEMATICAL APPLIED PRICE MAPPING (Eliminates Off-by-One Mismatch)
   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-((int)InpSourcePrice) - 1) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(volume_limit > 0 && InpSignalType == SIGNAL_MA && InpSignalMethod == VWMA)
         g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, volume, BufferCycle, BufferSignal);
      else
         g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, tick_volume, BufferCycle, BufferSignal);

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars_mtf = 20;
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
         ArrayResize(h_res_cycle,  g_htf_count, 2048);
         ArrayResize(h_res_signal, g_htf_count, 2048);

         ArraySetAsSeries(h_time,       false);
         ArraySetAsSeries(h_open,       false);
         ArraySetAsSeries(h_high,       false);
         ArraySetAsSeries(h_low,        false);
         ArraySetAsSeries(h_close,      false);
         ArraySetAsSeries(h_vol,        false);
         ArraySetAsSeries(h_res_cycle,  false);
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

      // Compute HTF Cyber Cycle & Signal Line on Clean HTF Domain
      g_calculator.Calculate(g_htf_count, 0, price_type, h_open, h_high, h_low, h_close, h_vol,
                             h_res_cycle, h_res_signal);
      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufferCycle[i]  = EMPTY_VALUE;
            BufferSignal[i] = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         BufferCycle[i]  = h_res_cycle[htf_ptr];
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
         g_calculator.Calculate(g_htf_count, g_htf_count, price_type, h_open, h_high, h_low, h_close, h_vol,
                                h_res_cycle, h_res_signal);
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

   double val_cycle  = h_res_cycle[live_idx];
   double val_signal = h_res_signal[live_idx];

   for(int i = start; i < rates_total; i++)
     {
      BufferCycle[i]  = val_cycle;
      BufferSignal[i] = val_signal;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = 20 + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
