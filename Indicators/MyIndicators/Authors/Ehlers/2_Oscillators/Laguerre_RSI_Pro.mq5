//+------------------------------------------------------------------+
//|                                             Laguerre_RSI_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.10" // Enterprise Refactor: Zero-Lag MTF Fast-Path & Zero-Copy Memory
#property description "John Ehlers' Laguerre Relative Strength Index with Native & MTF Support."
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
#property indicator_width1  1

//--- Included Engines & Core Tools
#include <MyIncludes\Laguerre_RSI_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Enum for Display Mode ---
#ifndef ENUM_LRSI_DISPLAY_MODE_DEFINED
#define ENUM_LRSI_DISPLAY_MODE_DEFINED
enum ENUM_LRSI_DISPLAY_MODE
  {
   DISPLAY_LRSI_ONLY,
   DISPLAY_LRSI_AND_SIGNAL
  };
#endif

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;          // Calculation Timeframe (Current or HTF)

input group "--- Laguerre RSI Settings ---"
input double                    InpGamma          = 0.5;                     // Gamma (e.g. 0.236, 0.382, 0.500, 0.618)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;         // Price Source (Standard / HA)

input group "--- Signal Line Settings ---"
input ENUM_LRSI_DISPLAY_MODE    InpDisplayMode    = DISPLAY_LRSI_AND_SIGNAL; // Display Mode
input int                       InpSignalPeriod   = 3;                       // Signal Period
input ENUM_MA_TYPE              InpSignalMAType   = EMA;                     // Signal MA Type (Supports VWMA)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Indicator Levels (0-100 Range) ---"
input double                    InpLevelExtrHigh  = 90.0;                    // Extreme Overbought Level
input double                    InpLevelHigh      = 80.0;                    // Overbought Warning Level
input double                    InpLevelMid       = 50.0;                    // Equilibrium Level
input double                    InpLevelLow       = 20.0;                    // Oversold Warning Level
input double                    InpLevelExtrLow   = 10.0;                    // Extreme Oversold Level
input color                     InpLevelColor     = clrSilver;               // Level Lines Color
input ENUM_LINE_STYLE           InpLevelStyle     = STYLE_DOT;               // Level Lines Style

input group "--- Visual Settings ---"
input color                     InpColorLRSI      = clrMediumTurquoise;      // Laguerre RSI Line Color
input ENUM_LINE_STYLE           InpStyleLRSI      = STYLE_SOLID;             // Laguerre RSI Line Style
input int                       InpWidthLRSI      = 2;                       // Laguerre RSI Line Width

input color                     InpColorSignal    = clrLightCoral;           // Signal Line Color
input ENUM_LINE_STYLE           InpStyleSignal    = STYLE_SOLID;             // Signal Line Style
input int                       InpWidthSignal    = 1;                       // Signal Line Width

//--- Indicator Buffers ---
double    BufferLRSI[];
double    BufferSignal[];

//--- Internal HTF Data Caches
double    h_open[], h_high[], h_low[], h_close[];
long      h_volume[];
double    h_res_lrsi[], h_res_signal[];
datetime  h_time[];

//--- Global Objects & State Management
CLaguerreRSICalculator *g_calculator = NULL;

bool            g_is_mtf_mode   = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready    = false;
bool            g_data_synced   = false;
int             g_htf_count     = 0;
datetime        g_last_htf_time = 0;

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

// 2. Bind Buffers
   SetIndexBuffer(0, BufferLRSI,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferLRSI,   false);
   ArraySetAsSeries(BufferSignal, false);

   ArrayInitialize(BufferLRSI,   EMPTY_VALUE);
   ArrayInitialize(BufferSignal, EMPTY_VALUE);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling
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

// Configure Horizontal Levels
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

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
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

// 5. Initialize Background Synchronization Timer (Only for MTF mode)
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_is_mtf_mode)
      EventKillTimer();

   if(CheckPointer(g_calculator) != POINTER_INVALID)
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
   if(rates_total < required_bars || !g_calculator)
      return 0;

// Force chronological indexing
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

      if(InpDisplayMode == DISPLAY_LRSI_ONLY)
        {
         int start_sync = (prev_calculated > 0) ? prev_calculated - 1 : 0;
         for(int i = start_sync; i < rates_total; i++)
            BufferSignal[i] = EMPTY_VALUE;
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

// A) HTF Bar Closure / Startup: Perform full history sync once
   if(htf_updated || prev_calculated == 0)
     {
      g_last_htf_time = htf_time_current;

      int htf_bars = iBars(_Symbol, g_calc_timeframe);
      if(htf_bars < required_bars)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 3000); // Memory safeguard

      // Resize all HTF caching arrays
      ArrayResize(h_time,       g_htf_count);
      ArrayResize(h_open,       g_htf_count);
      ArrayResize(h_high,       g_htf_count);
      ArrayResize(h_low,        g_htf_count);
      ArrayResize(h_close,      g_htf_count);
      ArrayResize(h_volume,     g_htf_count);
      ArrayResize(h_res_lrsi,   g_htf_count);
      ArrayResize(h_res_signal, g_htf_count);

      ArraySetAsSeries(h_time,       false);
      ArraySetAsSeries(h_open,       false);
      ArraySetAsSeries(h_high,       false);
      ArraySetAsSeries(h_low,        false);
      ArraySetAsSeries(h_close,      false);
      ArraySetAsSeries(h_volume,     false);
      ArraySetAsSeries(h_res_lrsi,   false);
      ArraySetAsSeries(h_res_signal, false);

      // Atomic bulk rates copy (Single API call replaces 6 calls!)
      MqlRates htf_bulk_rates[];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, g_htf_count, htf_bulk_rates) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

      for(int i = 0; i < g_htf_count; i++)
        {
         h_time[i]   = htf_bulk_rates[i].time;
         h_open[i]   = htf_bulk_rates[i].open;
         h_high[i]   = htf_bulk_rates[i].high;
         h_low[i]    = htf_bulk_rates[i].low;
         h_close[i]  = htf_bulk_rates[i].close;
         h_volume[i] = (vol_limit > 0 && htf_bulk_rates[i].real_volume > 0) ? (long)htf_bulk_rates[i].real_volume : (long)htf_bulk_rates[i].tick_volume;
        }

      // Compute HTF Laguerre RSI Values across history
      if(use_vwma)
         g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_volume, h_res_lrsi, h_res_signal);
      else
         g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_res_lrsi, h_res_signal);

      g_data_ready = true;

      // Full Historical Projection to Chart Buffers (Only on new HTF candle)
      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);
         if(shift_htf >= 0)
           {
            int idx_htf = g_htf_count - 1 - shift_htf;
            if(idx_htf >= 0 && idx_htf < g_htf_count)
              {
               BufferLRSI[i]   = h_res_lrsi[idx_htf];
               BufferSignal[i] = (InpDisplayMode == DISPLAY_LRSI_AND_SIGNAL) ? h_res_signal[idx_htf] : EMPTY_VALUE;
              }
            else
              {
               BufferLRSI[i] = EMPTY_VALUE;
               BufferSignal[i] = EMPTY_VALUE;
              }
           }
         else
           {
            BufferLRSI[i] = EMPTY_VALUE;
            BufferSignal[i] = EMPTY_VALUE;
           }
        }
      return rates_total;
     }

   if(!g_data_ready)
      return 0;

// B) LIVE TICK FAST-PATH: HTF bar did not close. Update strictly forming block!
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      MqlRates htf_rate[1];
      // Single atomic API call instead of 5 separate copies!
      if(CopyRates(_Symbol, g_calc_timeframe, 0, 1, htf_rate) == 1)
        {
         h_time[live_idx]  = htf_rate[0].time;
         h_open[live_idx]  = htf_rate[0].open;
         h_high[live_idx]  = htf_rate[0].high;
         h_low[live_idx]   = htf_rate[0].low;
         h_close[live_idx] = htf_rate[0].close;

         long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
         h_volume[live_idx] = (vol_limit > 0 && htf_rate[0].real_volume > 0) ? (long)htf_rate[0].real_volume : (long)htf_rate[0].tick_volume;

         // Mock update strictly on forming candle
         if(use_vwma)
            g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_volume, h_res_lrsi, h_res_signal);
         else
            g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_res_lrsi, h_res_signal);
        }
     }

// Instant Binary Search for Forming Block Start (Zero iBarShift API calls!)
   int first_bar_of_forming_htf = ArrayBsearch(time, htf_time_current);
   if(first_bar_of_forming_htf < 0)
      first_bar_of_forming_htf = 0;
   if(time[first_bar_of_forming_htf] < htf_time_current && first_bar_of_forming_htf < rates_total - 1)
      first_bar_of_forming_htf++;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

// Direct Vectorized Assignment (Zero API calls, Nanosecond Execution across 2 buffers)
   double lrsi_val = h_res_lrsi[live_idx];
   double sig_val  = (InpDisplayMode == DISPLAY_LRSI_AND_SIGNAL) ? h_res_signal[live_idx] : EMPTY_VALUE;

   for(int i = start; i < rates_total; i++)
     {
      BufferLRSI[i]   = lrsi_val;
      BufferSignal[i] = sig_val;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = InpSignalPeriod + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
