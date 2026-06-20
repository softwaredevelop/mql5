//+------------------------------------------------------------------+
//|                                   Autocorrelation_MTF_Pro.mq5    |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.20" // Optimized with Forming LTF Block Flat-Force mechanism
#property description "Lag-1 Autocorrelation (Multi-Timeframe)."
#property description "Displays Higher Timeframe Serial Correlation regime cleanly without live-bar warping."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Plot: Histogram
#property indicator_label1  "Autocorrelation MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: MeanRev(Red), Random(Gray), Trend(Green)
#property indicator_color1  clrCrimson, clrGray, clrSpringGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\Autocorrelation_Calculator.mqh>

//--- Parameters
input ENUM_TIMEFRAMES   InpTimeframe   = PERIOD_M5;    // Target Higher Timeframe
input int               InpPeriod      = 20;           // Window Size
input double            InpThreshold   = 0.1;          // Significance Threshold
input ENUM_APPLIED_PRICE InpPrice      = PRICE_CLOSE;  // Applied Price

//--- Buffers
double BufAC[];
double BufCol[];

//--- Internal HTF Data Caches
double h_open[], h_high[], h_low[], h_close[];
datetime h_time[];
double h_res[]; // HTF calculation results cached

//--- Global HTF State Tracking
CAutocorrelationCalculator *g_calc;
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
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready = false;
   g_data_synced = false;
   g_last_htf_time = 0;
   g_htf_count = 0;

   if(InpTimeframe <= Period() && InpTimeframe != PERIOD_CURRENT)
     {
      Print("Warning: Target Timeframe should be > Current Timeframe.");
     }

   SetIndexBuffer(0, BufAC, INDICATOR_DATA);
   SetIndexBuffer(1, BufCol, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(BufAC, false);
   ArraySetAsSeries(BufCol, false);

   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string name = StringFormat("Autocorrelation MTF %s(%d)", tf_name, InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 3);

   g_calc = new CAutocorrelationCalculator();
   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpPeriod))
     {
      Print("Error: Failed to initialize Autocorrelation Calculator Engine.");
      return INIT_FAILED;
     }

//--- Initialize 1-second timer for weekend/async chart refreshes
   EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   EventKillTimer();
   if(CheckPointer(g_calc) != POINTER_INVALID)
      delete g_calc;
  }

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
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
      ArrayResize(h_res,   g_htf_count);

      if(CopyTime(_Symbol,  InpTimeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  InpTimeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  InpTimeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   InpTimeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, InpTimeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      //--- Calculate Autocorrelation on HTF (Closed bars and forming bar initialized)
      g_calc.Calculate(g_htf_count, 0, InpPrice, h_open, h_high, h_low, h_close, h_res);

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 2. Live Update for the Current Forming HTF Bar (Index: g_htf_count - 1) on every tick!
   int live_idx = g_htf_count - 1;
   if(live_idx >= InpPeriod + 1)
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
         g_calc.Calculate(g_htf_count, live_idx, InpPrice, h_open, h_high, h_low, h_close, h_res);
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
            double val = h_res[idx_htf];
            BufAC[i] = val;

            // Color Logic
            if(val > InpThreshold)
               BufCol[i] = 2.0; // Green (Momentum / Trend)
            else
               if(val < -InpThreshold)
                  BufCol[i] = 0.0; // Red (Mean Reversion)
               else
                  BufCol[i] = 1.0; // Gray (Random Noise)
           }
         else
           {
            BufAC[i] = EMPTY_VALUE;
            BufCol[i] = 1.0;
           }
        }
      else
        {
         BufAC[i] = EMPTY_VALUE;
         BufCol[i] = 1.0;
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
