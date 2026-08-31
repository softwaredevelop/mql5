//+------------------------------------------------------------------+
//|                                      Laguerre_Stoch_Slow_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Unified Native & MTF Release with Dynamic Levels
#property description "John Ehlers' Laguerre Stochastic Slow Oscillator with Native & MTF Support."
#property description "Calculates Stochastic from Laguerre state components (L0-L3) with dual MA smoothing."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_minimum 0.0
#property indicator_maximum 100.0

//--- Plot 1: Slow %K
#property indicator_label1  "Slow %K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Signal %D
#property indicator_label2  "Signal %D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrCoral
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Included Engines & Core Tools
#include <MyIncludes\Laguerre_Stoch_Slow_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;      // Calculation Timeframe (Current or HTF)

input group "--- Laguerre Settings ---"
input double                    InpGamma          = 0.7;                 // Gamma (e.g. 0.236, 0.382, 0.618, 0.764)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;     // Price Source (Standard / HA)

input group "--- Stochastic Slowing & Signal Settings ---"
input int                       InpSlowingPeriod  = 3;                   // Smoothing for Raw %K
input ENUM_MA_TYPE              InpSlowingMethod  = SMA;                 // Method for Slowing
input int                       InpSignalPeriod   = 3;                   // Signal Line Period (%D)
input ENUM_MA_TYPE              InpSignalMethod   = SMA;                 // Method for Signal

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Indicator Levels (0-100 Range) ---"
input double                    InpLevelExtrHigh  = 90.0;                // Extreme Overbought Level
input double                    InpLevelHigh      = 80.0;                // Overbought Warning Level
input double                    InpLevelMid       = 50.0;                // Equilibrium Level
input double                    InpLevelLow       = 20.0;                // Oversold Warning Level
input double                    InpLevelExtrLow   = 10.0;                // Extreme Oversold Level
input color                     InpLevelColor     = clrSilver;           // Level Lines Color
input ENUM_LINE_STYLE           InpLevelStyle     = STYLE_DOT;           // Level Lines Style

input group "--- Visual Settings ---"
input color                     InpColorK         = clrDodgerBlue;       // %K Line Color
input ENUM_LINE_STYLE           InpStyleK         = STYLE_SOLID;         // %K Line Style
input int                       InpWidthK         = 2;                   // %K Line Width

input color                     InpColorD         = clrCoral;            // %D Line Color
input ENUM_LINE_STYLE           InpStyleD         = STYLE_SOLID;         // %D Line Style
input int                       InpWidthD         = 1;                   // %D Line Width

//--- Indicator Buffers ---
double    BufferSlowK[];
double    BufferSignalD[];

//--- Internal HTF Data Caches (Chronological Arrays)
double    h_open[], h_high[], h_low[], h_close[];
long      h_tick_vol[], h_vol[];
double    h_res_k[], h_res_d[];
datetime  h_time[];

//--- Global Objects & State Management
CLaguerreStochSlowCalculator *g_calculator = NULL;

bool            g_is_mtf_mode         = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready          = false;
bool            g_data_synced         = false;
int             g_htf_count           = 0;
datetime        g_last_htf_time       = 0;

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
   SetIndexBuffer(0, BufferSlowK,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignalD, INDICATOR_DATA);

   ArraySetAsSeries(BufferSlowK,   false);
   ArraySetAsSeries(BufferSignalD, false);

   ArrayInitialize(BufferSlowK,   EMPTY_VALUE);
   ArrayInitialize(BufferSignalD, EMPTY_VALUE);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorK);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleK);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthK);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorD);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleD);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthD);

// Configure Horizontal Levels
   IndicatorSetInteger(INDICATOR_LEVELS, 5);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpLevelExtrLow);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpLevelLow);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, InpLevelMid);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, InpLevelHigh);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 4, InpLevelExtrHigh);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, InpLevelColor);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, InpLevelStyle);

   int draw_begin = InpSlowingPeriod + InpSignalPeriod + 2;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

// 4. Initialize Core Calculator Engine
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CLaguerreStochSlowCalculator_HA();
   else
      g_calculator = new CLaguerreStochSlowCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpGamma, InpSlowingPeriod, InpSlowingMethod, InpSignalPeriod, InpSignalMethod, InpSourcePrice))
     {
      Print("Critical Error: Failed to initialize Laguerre Stoch Slow Calculator.");
      return INIT_FAILED;
     }

   string ha_tag = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("Laguerre Stoch Slow%s%s(γ=%.3f, %d, %d)",
                                    ha_tag, tf_str, InpGamma, InpSlowingPeriod, InpSignalPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

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
   int warmup = InpSlowingPeriod + InpSignalPeriod + 4;
   if(rates_total < warmup || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Force chronological indexing
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
         g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, volume, BufferSlowK, BufferSignalD);
      else
         g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, tick_volume, BufferSlowK, BufferSignalD);

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (Warp-free Step Synchronization)
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

      // Resize all HTF caching arrays
      ArrayResize(h_time,     g_htf_count);
      ArrayResize(h_open,     g_htf_count);
      ArrayResize(h_high,     g_htf_count);
      ArrayResize(h_low,      g_htf_count);
      ArrayResize(h_close,    g_htf_count);
      ArrayResize(h_tick_vol, g_htf_count);
      ArrayResize(h_vol,      g_htf_count);
      ArrayResize(h_res_k,    g_htf_count);
      ArrayResize(h_res_d,    g_htf_count);

      ArraySetAsSeries(h_time,     false);
      ArraySetAsSeries(h_open,     false);
      ArraySetAsSeries(h_high,     false);
      ArraySetAsSeries(h_low,      false);
      ArraySetAsSeries(h_close,    false);
      ArraySetAsSeries(h_tick_vol, false);
      ArraySetAsSeries(h_vol,      false);
      ArraySetAsSeries(h_res_k,    false);
      ArraySetAsSeries(h_res_d,    false);

      if(CopyTime(_Symbol,       g_calc_timeframe, 0, g_htf_count, h_time)     != g_htf_count ||
         CopyOpen(_Symbol,       g_calc_timeframe, 0, g_htf_count, h_open)     != g_htf_count ||
         CopyHigh(_Symbol,       g_calc_timeframe, 0, g_htf_count, h_high)     != g_htf_count ||
         CopyLow(_Symbol,        g_calc_timeframe, 0, g_htf_count, h_low)      != g_htf_count ||
         CopyClose(_Symbol,      g_calc_timeframe, 0, g_htf_count, h_close)    != g_htf_count ||
         CopyTickVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, h_tick_vol) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(vol_limit > 0)
         CopyRealVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, h_vol);
      else
         ArrayCopy(h_vol, h_tick_vol, 0, 0, g_htf_count);

      // Compute HTF Laguerre Stochastic Values
      if(vol_limit > 0)
         g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_vol, h_res_k, h_res_d);
      else
         g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_tick_vol, h_res_k, h_res_d);

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

// 5. Stateful live-bar update for active forming HTF candle
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      double o[1], h[1], l[1], c[1];
      long tv[1], v[1];

      int shift = iBarShift(_Symbol, g_calc_timeframe, htf_time_current, false);
      if(shift >= 0 &&
         CopyOpen(_Symbol,       g_calc_timeframe, shift, 1, o)  == 1 &&
         CopyHigh(_Symbol,       g_calc_timeframe, shift, 1, h)  == 1 &&
         CopyLow(_Symbol,        g_calc_timeframe, shift, 1, l)  == 1 &&
         CopyClose(_Symbol,      g_calc_timeframe, shift, 1, c)  == 1 &&
         CopyTickVolume(_Symbol, g_calc_timeframe, shift, 1, tv) == 1)
        {
         h_open[live_idx]     = o[0];
         h_high[live_idx]     = h[0];
         h_low[live_idx]      = l[0];
         h_close[live_idx]    = c[0];
         h_tick_vol[live_idx] = tv[0];

         long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
         if(vol_limit > 0 && CopyRealVolume(_Symbol, g_calc_timeframe, shift, 1, v) == 1)
            h_vol[live_idx] = v[0];
         else
            h_vol[live_idx] = tv[0];

         // Mock update on live HTF bar
         if(vol_limit > 0)
            g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_vol, h_res_k, h_res_d);
         else
            g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_tick_vol, h_res_k, h_res_d);
        }
     }

// 6. Forming LTF Block Flat-Force Anchor (The Staircase Solution)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   int first_bar_of_forming_htf = rates_total - 1;
   while(first_bar_of_forming_htf > 0 &&
         iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
     {
      first_bar_of_forming_htf--;
     }
   first_bar_of_forming_htf++;

   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

// 7. Chronological Mapping Loop to Chart Timeframe (2 Buffers)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufferSlowK[i]   = h_res_k[idx_htf];
            BufferSignalD[i] = h_res_d[idx_htf];
           }
         else
           {
            BufferSlowK[i]   = EMPTY_VALUE;
            BufferSignalD[i] = EMPTY_VALUE;
           }
        }
      else
        {
         BufferSlowK[i]   = EMPTY_VALUE;
         BufferSignalD[i] = EMPTY_VALUE;
        }
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int warmup = InpSlowingPeriod + InpSignalPeriod + 4;
   int required_bars = warmup + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
