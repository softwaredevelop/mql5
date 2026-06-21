//+------------------------------------------------------------------+
//|                                     VolatilityRegime_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.20" // Optimized with Forming LTF Block Flat-Force and OnTimer Guard
#property description "Volatility Regime (Multi-Timeframe)."
#property description "Displays Higher Timeframe ATR Ratio (Fast/Slow) cleanly without live-bar warping."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Level 1.0
#property indicator_level1 1.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot: Regime Histogram
#property indicator_label1  "Vola Ratio MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: Contracting(Gray), Expanding(Lime)
#property indicator_color1  clrGray, clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\ATR_Calculator.mqh>

//--- Input Parameters
input ENUM_TIMEFRAMES   InpTimeframe      = PERIOD_H1;    // Target Timeframe
input int               InpPeriodFast     = 5;            // Short-term Volatility
input int               InpPeriodSlow     = 50;           // Long-term Baseline
input double            InpThreshold      = 1.0;          // Expansion Threshold

//--- Buffers
double BufRatio[];
double BufColor[];

//--- Internal HTF Data Caches
double h_open[], h_high[], h_low[], h_close[];
datetime h_time[];

double h_atr_f[], h_atr_s[]; // HTF ATR results cached
double h_res[]; // HTF Ratio results cached

//--- Global HTF State Tracking
CATRCalculator *g_atr_fast;
CATRCalculator *g_atr_slow;
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
     {
      Print("Warning: Target Timeframe should be > Current Timeframe.");
     }

   SetIndexBuffer(0, BufRatio, INDICATOR_DATA);
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(BufRatio, false);
   ArraySetAsSeries(BufColor, false);

   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string name = StringFormat("VolaRegime MTs %s(%d/%d)", tf_name, InpPeriodFast, InpPeriodSlow);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   g_atr_fast = new CATRCalculator();
   if(CheckPointer(g_atr_fast) == POINTER_INVALID || !g_atr_fast.Init(InpPeriodFast, ATR_POINTS))
      return INIT_FAILED;

   g_atr_slow = new CATRCalculator();
   if(CheckPointer(g_atr_slow) == POINTER_INVALID || !g_atr_slow.Init(InpPeriodSlow, ATR_POINTS))
      return INIT_FAILED;

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
   if(CheckPointer(g_atr_fast) != POINTER_INVALID)
      delete g_atr_fast;
   if(CheckPointer(g_atr_slow) != POINTER_INVALID)
      delete g_atr_slow;
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
   int required_bars = InpPeriodSlow + 10;
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

      ArrayResize(h_atr_f, g_htf_count);
      ArrayResize(h_atr_s, g_htf_count);
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

      //--- Calculate ATR on HTF (Closed bars and forming bar initialized)
      g_atr_fast.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_atr_f);
      g_atr_slow.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_atr_s);

      for(int i = 0; i < g_htf_count; i++)
        {
         if(h_atr_s[i] > 0)
            h_res[i] = h_atr_f[i] / h_atr_s[i];
         else
            h_res[i] = 1.0;
        }

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 2. Live Update for the Current Forming HTF Bar (Index: g_htf_count - 1) on every tick!
   int live_idx = g_htf_count - 1;
   if(live_idx >= InpPeriodSlow)
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
         g_atr_fast.Calculate(g_htf_count, live_idx, h_open, h_high, h_low, h_close, h_atr_f);
         g_atr_slow.Calculate(g_htf_count, live_idx, h_open, h_high, h_low, h_close, h_atr_s);

         if(h_atr_s[live_idx] > 0)
            h_res[live_idx] = h_atr_f[live_idx] / h_atr_s[live_idx];
         else
            h_res[live_idx] = 1.0;
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
            BufRatio[i] = val;

            // Color Logic
            if(val >= InpThreshold)
               BufColor[i] = 1.0; // Lime (Volatility Expanding / Active Market)
            else
               BufColor[i] = 0.0; // Gray (Volatility Contracting / Sleeping Market)
           }
         else
           {
            BufRatio[i] = EMPTY_VALUE;
            BufColor[i] = 0.0;
           }
        }
      else
        {
         BufRatio[i] = EMPTY_VALUE;
         BufColor[i] = 0.0;
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
      int required_bars = InpPeriodSlow + 5;
      if(EnsureHTFDataReady(_Symbol, InpTimeframe, required_bars))
        {
         g_data_synced = true;
         ChartRedraw(); // Force MT5 to invoke OnCalculate
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
