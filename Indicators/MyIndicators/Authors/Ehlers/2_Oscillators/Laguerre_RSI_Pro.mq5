//+------------------------------------------------------------------+
//|                                             Laguerre_RSI_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "4.00" // Enterprise Edition: Two-Pointer MTF Fast-Path, Atomic CopyRates & Full Visual Panel
#property description "John Ehlers' Laguerre Relative Strength Index with Native MTF Fast-Path."
#property description "Features time-warped zero-lag momentum analysis with optional smoothed signal line."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_minimum 0.0
#property indicator_maximum 100.0

//--- Plot 1: Laguerre RSI Line
#property indicator_label1  "Laguerre RSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumTurquoise
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Signal Line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLightCoral
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Included Engines & Core Tools ---
#include <MyIncludes\Laguerre_RSI_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Enum for Display Mode ---
#ifndef ENUM_LRSI_DISPLAY_MODE_DEFINED
#define ENUM_LRSI_DISPLAY_MODE_DEFINED
enum ENUM_LRSI_DISPLAY_MODE
  {
   DISPLAY_LRSI_ONLY,        // Laguerre RSI Only
   DISPLAY_LRSI_AND_SIGNAL   // Laguerre RSI + Signal Moving Average
  };
#endif

//--- Input Parameters ---
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;          // Calculation Timeframe (Current or HTF)

input group "=== Laguerre RSI Settings ==="
input double                    InpGamma          = 0.5;                     // Gamma Damping Factor (0.0 to 1.0)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;         // Price Source (Standard / HA)

input group "=== Signal Line Settings ==="
input ENUM_LRSI_DISPLAY_MODE    InpDisplayMode    = DISPLAY_LRSI_AND_SIGNAL; // Display Mode
input int                       InpSignalPeriod   = 3;                       // Signal MA Period
input ENUM_MA_TYPE              InpSignalMAType   = EMA;                     // Signal MA Algorithm (14 Pluggable Models)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "=== Indicator Levels (0-100 Range) ==="
input double                    InpLevelExtrHigh  = 90.0;                    // Extreme Overbought Level
input double                    InpLevelHigh      = 80.0;                    // Overbought Warning Level
input double                    InpLevelMid       = 50.0;                    // Equilibrium Level
input double                    InpLevelLow       = 20.0;                    // Oversold Warning Level
input double                    InpLevelExtrLow   = 10.0;                    // Extreme Oversold Level
input color                     InpLevelColor     = clrDarkGray;             // Level Lines Color
input ENUM_LINE_STYLE           InpLevelStyle     = STYLE_DOT;               // Level Lines Style

input group "=== Visual Settings - Laguerre RSI Line ==="
input color                     InpColorLRSI      = clrMediumTurquoise;      // Laguerre RSI Color
input ENUM_LINE_STYLE           InpStyleLRSI      = STYLE_SOLID;             // Laguerre RSI Style
input int                       InpWidthLRSI      = 2;                       // Laguerre RSI Width

input group "=== Visual Settings - Signal Line ==="
input color                     InpColorSignal    = clrLightCoral;           // Signal Line Color
input ENUM_LINE_STYLE           InpStyleSignal    = STYLE_SOLID;             // Signal Line Style
input int                       InpWidthSignal    = 1;                       // Signal Line Width

//--- Indicator Output Buffers ---
double BufferLRSI[];
double BufferSignal[];

//--- Internal HTF Data Caches (Chronological Arrays) ---
double   h_open[], h_high[], h_low[], h_close[];
double   h_vol[];
double   h_res_lrsi[], h_res_signal[];
datetime h_time[];

//--- Global Objects & State Management ---
CLaguerreRSICalculator *g_calculator     = NULL;
bool                   g_is_mtf_mode     = false;
ENUM_TIMEFRAMES        g_calc_timeframe;
bool                   g_data_ready      = false;
bool                   g_data_synced     = false;
int                    g_htf_count       = 0;
datetime               g_last_htf_time   = 0;

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
   SetIndexBuffer(0, BufferLRSI,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferLRSI,   false);
   ArraySetAsSeries(BufferSignal, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling & Visibility Control
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorLRSI);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleLRSI);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthLRSI);

   if(InpDisplayMode == DISPLAY_LRSI_AND_SIGNAL)
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorSignal);
      PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleSignal);
      PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthSignal);
      PlotIndexSetString(1,  PLOT_LABEL, "Signal");
     }
   else
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetString(1,  PLOT_LABEL, NULL);
     }

// Configure Reference Levels
   IndicatorSetInteger(INDICATOR_LEVELS, 5);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpLevelExtrLow);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpLevelLow);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, InpLevelMid);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, InpLevelHigh);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 4, InpLevelExtrHigh);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, InpLevelColor);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, InpLevelStyle);

   int draw_begin = InpSignalPeriod + 2;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_is_mtf_mode ? 0 : 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

// 4. Initialize Core Calculator Engine
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CLaguerreRSICalculator_HA();
   else
      g_calculator = new CLaguerreRSICalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpGamma, InpSignalPeriod, InpSignalMAType, InpSourcePrice))
     {
      Print("Critical Error: Failed to initialize Laguerre RSI Calculator.");
      return INIT_FAILED;
     }

   string ha_tag  = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str  = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string sig_str = (InpDisplayMode == DISPLAY_LRSI_AND_SIGNAL) ? StringFormat(" | %s(%d)", EnumToString(InpSignalMAType), InpSignalPeriod) : "";

   string short_name = StringFormat("Laguerre RSI%s%s(γ=%.3f)%s", ha_tag, tf_str, InpGamma, sig_str);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "Laguerre RSI");

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
   int required_bars = InpSignalPeriod + 10;
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

   bool use_vwma = (InpDisplayMode == DISPLAY_LRSI_AND_SIGNAL && InpSignalMAType == VWMA);

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      if(use_vwma)
        {
         long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
         if(volume_limit > 0)
            g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, volume, BufferLRSI, BufferSignal);
         else
            g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, tick_volume, BufferLRSI, BufferSignal);
        }
      else
        {
         g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferLRSI, BufferSignal);
        }

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
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
         ArrayResize(h_res_lrsi,   g_htf_count, 2048);
         ArrayResize(h_res_signal, g_htf_count, 2048);

         ArraySetAsSeries(h_time,       false);
         ArraySetAsSeries(h_open,       false);
         ArraySetAsSeries(h_high,       false);
         ArraySetAsSeries(h_low,        false);
         ArraySetAsSeries(h_close,      false);
         ArraySetAsSeries(h_vol,        false);
         ArraySetAsSeries(h_res_lrsi,   false);
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

      // Compute HTF Laguerre RSI Values across history
      if(use_vwma)
         g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_vol, h_res_lrsi, h_res_signal);
      else
         g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_res_lrsi, h_res_signal);

      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufferLRSI[i]   = EMPTY_VALUE;
            BufferSignal[i] = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         BufferLRSI[i]   = h_res_lrsi[htf_ptr];
         BufferSignal[i] = h_res_signal[htf_ptr];
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
         if(use_vwma)
            g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_vol, h_res_lrsi, h_res_signal);
         else
            g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_res_lrsi, h_res_signal);
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

   double val_lrsi = h_res_lrsi[live_idx];
   double val_sig  = h_res_signal[live_idx];

   for(int i = start; i < rates_total; i++)
     {
      BufferLRSI[i]   = val_lrsi;
      BufferSignal[i] = val_sig;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = InpSignalPeriod + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
