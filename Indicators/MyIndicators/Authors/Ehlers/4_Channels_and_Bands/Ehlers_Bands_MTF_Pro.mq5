//+------------------------------------------------------------------+
//|                                         Ehlers_Bands_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Refactored with state-safe caching and step-blocking Flat-Force mapping
#property description "Ehlers Bands (Multi-Timeframe)."
#property description "Displays Higher Timeframe Bands on Current Chart cleanly without live-bar warping."

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

// Plot 1: Upper Band
#property indicator_label1  "Upper MTF"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGray
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

// Plot 2: Lower Band
#property indicator_label2  "Lower MTF"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGray
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

// Plot 3: Middle Line
#property indicator_label3  "Middle MTF"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGray
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>
#include <MyIncludes\Ehlers_Bands_Calculator.mqh>

//--- Input Parameters
input group "Timeframe Settings"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_H1;        // Target Timeframe

input group                     "Smoother Settings"
input ENUM_SMOOTHER_TYPE        InpCenterlineType = SUPERSMOOTHER;    // Centerline Type
input int                       InpPeriod         = 20;               // Period
input double                    InpMultiplier     = 2.0;              // Deviation Multiplier
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;  // Price Source

//--- Buffers (Visual)
double BufUpper[];
double BufLower[];
double BufMiddle[];

//--- Internal HTF Data Caches
double    h_res_mid[];   // HTF Middle results cached
double    h_res_up[];    // HTF Upper results cached
double    h_res_lo[];    // HTF Lower results cached
datetime  h_time[];
double    h_open[], h_high[], h_low[], h_close[];

//--- Calculator
CEhlersBandsCalculator *g_calc;
bool                     g_is_mtf_mode = false;
ENUM_TIMEFRAMES            g_calc_timeframe;
bool                     g_data_ready  = false;
bool                     g_data_synced = false;
int                      g_htf_count   = 0;
datetime                 g_last_htf_time = 0;

//+------------------------------------------------------------------+
//| EnsureHTFDataReady                                               |
//+------------------------------------------------------------------+
bool EnsureHTFDataReady(const string symbol, const ENUM_TIMEFRAMES timeframe, const int required_bars)
  {
   ResetLastError();
   if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
     {
      SymbolSelect(symbol, true);
     }
   datetime times[];
   int copied = CopyTime(symbol, timeframe, 0, required_bars, times);
   return (copied >= required_bars);
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready = false;
   g_data_synced = false;
   g_htf_count = 0;
   g_last_htf_time = 0;

//--- 1. Resolve Timeframe
   g_calc_timeframe = InpTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

//--- 2. Validation
   if(g_calc_timeframe < Period())
     {
      Print("Error: Target timeframe must be >= current timeframe.");
      return(INIT_FAILED);
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

   SetIndexBuffer(0, BufUpper, INDICATOR_DATA);
   SetIndexBuffer(1, BufLower, INDICATOR_DATA);
   SetIndexBuffer(2, BufMiddle, INDICATOR_DATA);
   ArraySetAsSeries(BufUpper, false);
   ArraySetAsSeries(BufLower, false);
   ArraySetAsSeries(BufMiddle, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- 3. Initialize Calculator
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calc = new CEhlersBandsCalculator_HA();
   else
      g_calc = new CEhlersBandsCalculator();

   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpPeriod, InpMultiplier, InpCenterlineType))
     {
      Print("Failed to initialize Ehlers Bands Calculator.");
      return(INIT_FAILED);
     }

   string tf_name = StringSubstr(EnumToString(g_calc_timeframe), 7);
   string name = StringFormat("Ehlers Bands MTF %s(%d,%.1f)", tf_name, InpPeriod, InpMultiplier);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

   int draw_begin = InpPeriod;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

//--- Initialize 1-second timer for weekend/async chart refreshes (Only if MTF mode is active)
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   EventKillTimer();
   if(CheckPointer(g_calc) != POINTER_INVALID)
      delete g_calc;
  }

//+------------------------------------------------------------------+
//| Calculate                                                        |
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
   if(rates_total < 2)
      return(0);

   if(CheckPointer(g_calc) == POINTER_INVALID)
      return(0);

//--- Force strict chronological indexing for state-safety on input price arrays
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

//================================================================
// MODE 1: Current Timeframe (Standard)
//================================================================
   if(!g_is_mtf_mode)
     {
      g_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufUpper, BufLower, BufMiddle);
      return(rates_total);
     }

//================================================================
// MODE 2: Multi-Timeframe (MTF Engine)
//================================================================

//--- Ensure target timeframe history is ready
   int required_bars = InpPeriod + 10;
   if(!EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars))
     {
      g_data_synced = false;
      return 0; // Wait for next tick to let history load
     }

   g_data_synced = true;

//--- 1. Check if a new HTF bar has formed
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

      ArrayResize(h_time,       g_htf_count);
      ArrayResize(h_open,       g_htf_count);
      ArrayResize(h_high,       g_htf_count);
      ArrayResize(h_low,        g_htf_count);
      ArrayResize(h_close,      g_htf_count);

      ArrayResize(h_res_mid,    g_htf_count);
      ArrayResize(h_res_up,     g_htf_count);
      ArrayResize(h_res_lo,     g_htf_count);

      // Force chronological array alignment on HTF caches after resize
      ArraySetAsSeries(h_time,  false);
      ArraySetAsSeries(h_open,  false);
      ArraySetAsSeries(h_high,  false);
      ArraySetAsSeries(h_low,   false);
      ArraySetAsSeries(h_close, false);

      if(CopyTime(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   g_calc_timeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, g_calc_timeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      //--- Calculate Smoother on HTF (Closed bars and forming bar initialized)
      g_calc.Calculate(g_htf_count, 0, price_type, h_open, h_high, h_low, h_close, h_res_up, h_res_lo, h_res_mid);

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 2. Live Update for the Current Forming HTF Bar (Index: g_htf_count - 1) on every tick!
   int live_idx = g_htf_count - 1;
   if(live_idx >= InpPeriod)
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

         // Incremental recalculation on the live HTF index in O(1)
         // Passed g_htf_count as prev_calculated to preserve state safety
         g_calc.Calculate(g_htf_count, g_htf_count, price_type, h_open, h_high, h_low, h_close, h_res_up, h_res_lo, h_res_mid);
        }
     }

//--- 3. FIXED: Dynamically adjust 'start' to the beginning of the current forming HTF bar
//--- This forces the entire forming LTF step block to remain perfectly flat, updating on every tick!
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   int first_bar_of_forming_htf = rates_total - 1;
   while(first_bar_of_forming_htf > 0 &&
         iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
     {
      first_bar_of_forming_htf--;
     }
   first_bar_of_forming_htf++; // This is the start of the forming step on lower TF chart

   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

//--- 4. Incremental Mapping of HTF results to Current Chart Timeframe (O(1) per tick)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufUpper[i]  = h_res_up[idx_htf];
            BufLower[i]  = h_res_lo[idx_htf];
            BufMiddle[i] = h_res_mid[idx_htf];
           }
         else
           {
            BufUpper[i]  = EMPTY_VALUE;
            BufLower[i]  = EMPTY_VALUE;
            BufMiddle[i] = EMPTY_VALUE;
           }
        }
      else
        {
         BufUpper[i]  = EMPTY_VALUE;
         BufLower[i]  = EMPTY_VALUE;
         BufMiddle[i] = EMPTY_VALUE;
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| OnTimer                                                          |
//| Handles loading checks and force-redraws                         |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(!g_data_synced)
     {
      int required_bars = InpPeriod + 5;
      if(EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars))
        {
         g_data_synced = true;
         ChartRedraw(); // Force MT5 to invoke OnCalculate
        }
     }
  }
//+------------------------------------------------------------------+
