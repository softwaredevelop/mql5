//+------------------------------------------------------------------+
//|                                            LinReg_R2_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.20" // Optimized with Forming LTF Block Flat-Force, OnTimer Guard and Heikin Ashi support
#property description "Linear Regression R-Squared & Slope (Multi-Timeframe)."
#property description "Measures Trend Quality of higher timeframe cleanly without live-bar warping."

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   2

// Levels for R2
#property indicator_level1 0.7
#property indicator_level2 0.3
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT
#property indicator_maximum 1.0
#property indicator_minimum 0.0

// Plot 1: R-Squared (Histogram)
#property indicator_label1  "R2 MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: Chop(Gray), Weak(Orange), Strong(Lime)
#property indicator_color1  clrGray, clrOrange, clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// Plot 2: Slope (Hidden on chart, shown in Data Window)
#property indicator_label2  "Slope MTF"
#property indicator_type2   DRAW_NONE
#property indicator_color2  clrGold

#include <MyIncludes\LinearRegression_Calculator.mqh>

//--- Parameters
input ENUM_TIMEFRAMES           InpTimeframe   = PERIOD_M5;    // Target Higher Timeframe
input int                       InpPeriod      = 20;           // Regression Period
input double            InpTrendLevel  = 0.7;          // Strong Trend Level (R2)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD; // Applied Price

//--- Buffers
double BufR2[];
double BufColors[];
double BufSlope[];
double BufForecast[]; // Helper calculation buffer (No Plot)

//--- Internal HTF Data Caches
double h_open[], h_high[], h_low[], h_close[];
double h_s[], h_r2[], h_f[]; // HTF Results cached
datetime h_time[];

//--- Global HTF State Tracking
CLinearRegressionCalculator *g_calc;
datetime                 g_last_htf_time     = 0;
int                      g_htf_count         = 0;
bool                     g_data_ready        = false;
bool                     g_data_synced       = false;

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
   g_last_htf_time = 0;
   g_htf_count = 0;

   if(InpTimeframe <= Period() && InpTimeframe != PERIOD_CURRENT)
      Print("Warning: Target Timeframe should be > Current for proper MTF usage.");

   SetIndexBuffer(0, BufR2,       INDICATOR_DATA);
   SetIndexBuffer(1, BufColors,  INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufSlope,    INDICATOR_DATA); // Map to INDICATOR_DATA for Data Window visibility
   SetIndexBuffer(3, BufForecast, INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufR2,       false);
   ArraySetAsSeries(BufColors,  false);
   ArraySetAsSeries(BufSlope,    false);
   ArraySetAsSeries(BufForecast, false);

//--- Configure dynamic calculator based on price source (Heikin Ashi support)
   bool use_ha = (InpSourcePrice <= PRICE_HA_CLOSE);
   if(use_ha)
      g_calc = new CLinearRegressionCalculator_HA();
   else
      g_calc = new CLinearRegressionCalculator();

   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpPeriod))
      return INIT_FAILED;

//--- Shortname generation
   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string short_name = StringFormat("R2 MTF %s(%d%s)", tf_name, InpPeriod, (use_ha ? " HA" : ""));
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "R2 MTF");
   PlotIndexSetString(1, PLOT_LABEL, "Slope MTF");
   IndicatorSetInteger(INDICATOR_DIGITS, 3);

//--- Initialize 1-second timer for weekend/async chart refreshes
   EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinit                                                           |
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
//--- Ensure target timeframe history is ready
   int required_bars = InpPeriod + 10;
   if(!EnsureHTFDataReady(_Symbol, InpTimeframe, required_bars))
     {
      g_data_synced = false;
      return 0; // Wait for next tick to let history load
     }

   g_data_synced = true;

//--- Convert custom HA price mapping back to standard ENUM_APPLIED_PRICE
   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- 1. Check if a new HTF bar has formed
   datetime htf_time_current = iTime(_Symbol, InpTimeframe, 0);
   bool htf_updated = (htf_time_current != g_last_htf_time);

   if(htf_updated || prev_calculated == 0)
     {
      g_last_htf_time = htf_time_current;

      int htf_bars = iBars(_Symbol, InpTimeframe);
      if(htf_bars < required_bars)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 3000);

      ArrayResize(h_time,  g_htf_count);
      ArrayResize(h_open,  g_htf_count);
      ArrayResize(h_high,  g_htf_count);
      ArrayResize(h_low,   g_htf_count);
      ArrayResize(h_close, g_htf_count);

      ArrayResize(h_s,     g_htf_count);
      ArrayResize(h_r2,    g_htf_count);
      ArrayResize(h_f,     g_htf_count);

      if(CopyTime(_Symbol,  InpTimeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  InpTimeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  InpTimeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   InpTimeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, InpTimeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      //--- Calculate regression states on HTF (Closed bars and forming bar initialized)
      g_calc.CalculateState(g_htf_count, 0, h_open, h_high, h_low, h_close, price_type, h_s, h_r2, h_f);

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 2. Live Update for the Current Forming HTF Bar (Index: g_htf_count - 1) on every tick!
   int live_idx = g_htf_count - 1;
   if(live_idx >= InpPeriod)
     {
      double o[1], h[1], l[1], c[1];
      int shift = iBarShift(_Symbol, InpTimeframe, htf_time_current, false);
      if(shift >= 0 &&
         CopyOpen(_Symbol,  InpTimeframe, shift, 1, o) == 1 &&
         CopyHigh(_Symbol,  InpTimeframe, shift, 1, h) == 1 &&
         CopyLow(_Symbol,   InpTimeframe, shift, 1, l) == 1 &&
         CopyClose(_Symbol, InpTimeframe, shift, 1, c) == 1)
        {
         h_open[live_idx]  = o[0];
         h_high[live_idx]  = h[0];
         h_low[live_idx]   = l[0];
         h_close[live_idx] = c[0];

         // Incremental recalculation on the live index (O(1) tick performance)
         g_calc.CalculateState(g_htf_count, live_idx, h_open, h_high, h_low, h_close, price_type, h_s, h_r2, h_f);
        }
     }

//--- 3. FIXED: Dynamically adjust 'start' to the beginning of the current forming HTF bar
//--- This forces the entire forming LTF step block to remain perfectly flat, updating on every tick!
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   int first_bar_of_forming_htf = rates_total - 1;
   while(first_bar_of_forming_htf > 0 &&
         iBarShift(_Symbol, InpTimeframe, time[first_bar_of_forming_htf], false) == 0)
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
      int shift_htf = iBarShift(_Symbol, InpTimeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            double r2 = h_r2[idx_htf];
            double sl = h_s[idx_htf];

            BufR2[i]    = r2;
            BufSlope[i] = sl;

            // Color Logic
            if(r2 >= InpTrendLevel)
               BufColors[i] = 2.0; // Index 2: Lime (Strong Trend)
            else
               if(r2 <= 0.3)
                  BufColors[i] = 0.0; // Index 0: Gray (Neutral Noise / Range)
               else
                  BufColors[i] = 1.0; // Index 1: Orange (Weak Trend / Transition)
           }
         else
           {
            BufR2[i]    = EMPTY_VALUE;
            BufSlope[i] = EMPTY_VALUE;
            BufColors[i] = 0.0;
           }
        }
      else
        {
         BufR2[i]    = EMPTY_VALUE;
         BufSlope[i] = EMPTY_VALUE;
         BufColors[i] = 0.0;
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
      if(EnsureHTFDataReady(_Symbol, InpTimeframe, required_bars))
        {
         g_data_synced = true;
         ChartRedraw(); // Force MT5 to invoke OnCalculate
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
