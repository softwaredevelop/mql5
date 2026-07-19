//+------------------------------------------------------------------+
//|                                  Laguerre_Adaptive_Channel_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Upgraded with dedicated ENUM_CHANNEL_WIDTH_METHOD for strict UI safety
#property description "Volatility channel around John Ehlers' Adaptive Laguerre Filter baseline."
#property description "Supports ER, ATR, and Standard Deviation dynamic bands."

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Plot 1: Adaptive Baseline (Keltner Median Line)
#property indicator_label1  "Adaptive Baseline"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Upper Volatility Band
#property indicator_label2  "Upper Band"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSlateGray
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Plot 3: Lower Volatility Band
#property indicator_label3  "Lower Band"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSlateGray
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- Included Engines & Core Tools
#include <MyIncludes\Laguerre_Adaptive_Channel_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh> // Centralized MTF synchronization daemon

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;       // Target Higher Timeframe

input group "--- Adaptive Baseline Settings ---"
input ENUM_ADAPTIVE_METHOD      InpAdaptiveMethod = METHOD_EFFICIENCY_RATIO; // Adaptive Baseline Method
input int                       InpAdaptivePeriod = 10;                  // Volatility/ER/StDev Period
input double                    InpGammaMin       = 0.136;               // Minimum Gamma (Max Speed)
input double                    InpGammaMax       = 0.882;               // Maximum Gamma (Max Smooth)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice     = PRICE_CLOSE_STD;     // Price Source

input group "--- Channel Width Settings ---"
input ENUM_CHANNEL_WIDTH_METHOD InpWidthMethod    = WIDTH_METHOD_ATR;    // Volatility Band Method (ATR/StDev)
input int                       InpWidthPeriod    = 10;                  // Volatility Band Lookback Period
input double                    InpMultiplier     = 2.0;                 // Volatility Band Multiplier

//--- Visual Indicator Buffers ---
double    BufferBaseline[];
double    BufferUpper[];
double    BufferLower[];

//--- Internal HTF Data Caches
double    h_open[], h_high[], h_low[], h_close[];
double    h_res_baseline[], h_res_upper[], h_res_lower[];
datetime  h_time[];

//--- Global Objects & Synchronizer State
CLaguerreAdaptiveChannelCalculator *g_calculator;

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

//--- 1. Resolve Timeframe and validate direction
   g_calc_timeframe = InpTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      PrintFormat("Critical Error: Target timeframe (%s) must be >= current timeframe (%s).",
                  EnumToString(g_calc_timeframe), EnumToString(Period()));
      return(INIT_FAILED);
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

//--- 2. Bind buffers to index mapping
   SetIndexBuffer(0, BufferBaseline, INDICATOR_DATA);
   SetIndexBuffer(1, BufferUpper,    INDICATOR_DATA);
   SetIndexBuffer(2, BufferLower,    INDICATOR_DATA);

//--- Force strict chronological alignment (false = old to new)
   ArraySetAsSeries(BufferBaseline, false);
   ArraySetAsSeries(BufferUpper,    false);
   ArraySetAsSeries(BufferLower,    false);

   bool is_ha = (InpSourcePrice <= PRICE_HA_CLOSE);

//--- 3. Initialize Physical Adaptive Channel Calculator
   g_calculator = new CLaguerreAdaptiveChannelCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID)
     {
      Print("Critical Error: Failed to allocate Adaptive Channel Calculator memory.");
      return(INIT_FAILED);
     }

   if(!g_calculator.Init(InpAdaptiveMethod, InpAdaptivePeriod, InpGammaMin, InpGammaMax,
                         InpWidthMethod, InpWidthPeriod, InpMultiplier, is_ha))
     {
      Print("Critical Error: Failed to initialize Adaptive Channel Calculator.");
      return(INIT_FAILED);
     }

//--- 4. Dynamic Setup of Indicator Shortname
   string method_str = "";
   switch(InpAdaptiveMethod)
     {
      case METHOD_EFFICIENCY_RATIO:
         method_str = "ER";
         break;
      case METHOD_ATR:
         method_str = "ATR";
         break;
      case METHOD_STAND_DEV:
         method_str = "StDev";
         break;
     }

   string width_str = (InpWidthMethod == WIDTH_METHOD_ATR) ? "ATR" : "StDev";

   string tf_str = g_is_mtf_mode ? (" " + EnumToString(g_calc_timeframe)) : "";
   string short_name = StringFormat("Laguerre Adaptive Channel%s%s(%s, %s, %.1f)",
                                    is_ha ? " HA" : "",
                                    tf_str,
                                    method_str,
                                    width_str,
                                    InpMultiplier);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

//--- Drawing offset configuration
   int draw_begin = MathMax(InpAdaptivePeriod * 2, InpWidthPeriod) + 10;
   if(g_is_mtf_mode)
      draw_begin = 0; // Handled dynamically in mapped buffers

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

//--- 5. Initialize Background Synchronization Timer Daemon (Only if MTF is active)
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
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
   int required_bars = MathMax(InpAdaptivePeriod * 2, InpWidthPeriod) + 15;
   if(rates_total < required_bars)
      return 0;

   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

//--- Force chronological indexing on current timeframe arrays
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

//===================================================================
// MODE 1: Current Timeframe calculation (Standard ultra-high speed)
//===================================================================
   if(!g_is_mtf_mode)
     {
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                             BufferBaseline, BufferUpper, BufferLower);
      return(rates_total);
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (Warp-free step synchronization)
//===================================================================
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars))
     {
      g_data_synced = false;
      return 0; // Wait for next tick to let history synchronize
     }

   g_data_synced = true;

//--- Check if a new HTF candle has opened
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

      g_htf_count = MathMin(htf_bars, 3000); // Guard rails to prevent memory overload

      // Resize all HTF caching arrays
      ArrayResize(h_time,          g_htf_count);
      ArrayResize(h_open,          g_htf_count);
      ArrayResize(h_high,          g_htf_count);
      ArrayResize(h_low,           g_htf_count);
      ArrayResize(h_close,         g_htf_count);
      ArrayResize(h_res_baseline,  g_htf_count);
      ArrayResize(h_res_upper,     g_htf_count);
      ArrayResize(h_res_lower,     g_htf_count);

      // Force chronological structure on high-level arrays
      ArraySetAsSeries(h_time,          false);
      ArraySetAsSeries(h_open,          false);
      ArraySetAsSeries(h_high,          false);
      ArraySetAsSeries(h_low,           false);
      ArraySetAsSeries(h_close,         false);
      ArraySetAsSeries(h_res_baseline,  false);
      ArraySetAsSeries(h_res_upper,     false);
      ArraySetAsSeries(h_res_lower,     false);

      // Copy basic pricing data
      if(CopyTime(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   g_calc_timeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, g_calc_timeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      //--- Calculate core indicators directly on high timeframe (Initial setup)
      g_calculator.Calculate(g_htf_count, 0, price_type, h_open, h_high, h_low, h_close, h_res_baseline, h_res_upper, h_res_lower);

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 5. Real-Time Update for the active forming HTF candle (Index: g_htf_count - 1) on every tick
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      double o[1], h[1], l[1], c[1];
      int shift = iBarShift(_Symbol, g_calc_timeframe, htf_time_current, false);
      if(shift >= 0 &&
         CopyOpen(_Symbol,  g_calc_timeframe, shift, 1, o) == 1 &&
         CopyHigh(_Symbol,  g_calc_timeframe, shift, 1, h) == 1 &&
         CopyLow(_Symbol,   g_calc_timeframe, shift, 1, l) == 1 &&
         CopyClose(_Symbol, g_calc_timeframe, shift, 1, c) == 1)
        {
         h_open[live_idx]  = o[0];
         h_high[live_idx]  = h[0];
         h_low[live_idx]   = l[0];
         h_close[live_idx] = c[0];

         // Stateful, O(1) mock update for the live bar
         g_calculator.Calculate(g_htf_count, g_htf_count, price_type, h_open, h_high, h_low, h_close, h_res_baseline, h_res_upper, h_res_lower);
        }
     }

//--- 6. Warp-free step force (Staircase Solution anchor determination)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   int first_bar_of_forming_htf = rates_total - 1;
   while(first_bar_of_forming_htf > 0 &&
         iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
     {
      first_bar_of_forming_htf--;
     }
   first_bar_of_forming_htf++; // Anchor set to start of current HTF period block

   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

//--- 7. Map HTF Calculated results cleanly to the lower chart timeframe (O(1) complexity)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufferBaseline[i] = h_res_baseline[idx_htf];
            BufferUpper[i]    = h_res_upper[idx_htf];
            BufferLower[i]    = h_res_lower[idx_htf];
           }
         else
           {
            BufferBaseline[i] = EMPTY_VALUE;
            BufferUpper[i]    = EMPTY_VALUE;
            BufferLower[i]    = EMPTY_VALUE;
           }
        }
      else
        {
         BufferBaseline[i] = EMPTY_VALUE;
         BufferUpper[i]    = EMPTY_VALUE;
         BufferLower[i]    = EMPTY_VALUE;
        }
     }

//--- Return of OnCalculate
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler                                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
//--- Delegate asynchronous history checking and forced redraws to DataSync daemon using correct lookback period
   int required_bars = MathMax(InpAdaptivePeriod * 2, InpWidthPeriod) + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
