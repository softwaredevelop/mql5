//+------------------------------------------------------------------+
//|                                     WeisWave_Duration_MTF_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Dynamic Multi-Timeframe Weis Wave Duration with retro-active SOT highlights
#property description "Professional Weis Wave Duration (Multi-Timeframe)."
#property description "Displays HTF Cumulative Wave Duration cleanly on current chart without live-bar warping."
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Plot: Color Histogram (Swapped with SOT colors)
#property indicator_label1  "Wave Duration MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Palette:
// 0: DodgerBlue (Normal Up Duration)
// 1: Crimson    (Normal Down Duration)
// 2: Orange     (Exhausted Up Duration / Bearish SOT)
// 3: Magenta    (Exhausted Down Duration / Bullish SOT)
#property indicator_color1  clrDodgerBlue, clrCrimson, clrOrange, clrFuchsia
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

#include <MyIncludes\WeisWave_Duration_Calculator.mqh>

//--- Input Parameters
input ENUM_TIMEFRAMES   InpTimeframe   = PERIOD_H1;    // Target Higher Timeframe
input int               InpATRPeriod   = 14;           // ATR Sensitivity Period
input double            InpMultiplier  = 2.5;          // Wave Reversal Multiplier (ATR)
input bool              InpShowSOT     = true;         // Highlight SOT (Momentum Exhaustion) waves?

//--- Buffers
double BufWaveDur[];
double BufColors[];

//--- Internal HTF Data Caches
double h_high[], h_low[], h_close[];
datetime h_time[];
double h_res_dur[], h_res_col[]; // HTF Results cached

//--- Global HTF State Tracking
CWeisWaveDurationCalculator *g_calc;
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

   SetIndexBuffer(0, BufWaveDur, INDICATOR_DATA);
   SetIndexBuffer(1, BufColors,  INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(BufWaveDur, false);
   ArraySetAsSeries(BufColors,  false);

   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string short_name = StringFormat("Weis Wave Duration MTF %s(%d, %.1f, SOT:%s)",
                                    tf_name, InpATRPeriod, InpMultiplier, (InpShowSOT ? "ON" : "OFF"));
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, 0);

   g_calc = new CWeisWaveDurationCalculator();
   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpATRPeriod, InpMultiplier))
     {
      Print("Error: Failed to initialize WeisWave Duration Calculator.");
      return INIT_FAILED;
     }

//--- Initialize 1-second timer for weekend/async chart refreshes
   EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
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
   int required_bars = InpATRPeriod + 20;
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
      ArrayResize(h_high,  g_htf_count);
      ArrayResize(h_low,   g_htf_count);
      ArrayResize(h_close, g_htf_count);

      ArrayResize(h_res_dur, g_htf_count);
      ArrayResize(h_res_col, g_htf_count);

      if(CopyTime(_Symbol,  InpTimeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyHigh(_Symbol,  InpTimeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   InpTimeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, InpTimeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      //--- Calculate Weis Wave Duration on HTF (Closed bars and forming bar initialized)
      g_calc.Calculate(g_htf_count, 0, h_high, h_low, h_close, h_res_dur, h_res_col, InpShowSOT);

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 2. Live Update for the Current Forming HTF Bar (Index: g_htf_count - 1) on every tick!
   int live_idx = g_htf_count - 1;
   if(live_idx >= InpATRPeriod)
     {
      double h[1], l[1], c[1];
      int shift = iBarShift(_Symbol, InpTimeframe, htf_time_current, false);
      if(shift >= 0 &&
         CopyHigh(_Symbol,  InpTimeframe, shift, 1, h) == 1 &&
         CopyLow(_Symbol,   InpTimeframe, shift, 1, l) == 1 &&
         CopyClose(_Symbol, InpTimeframe, shift, 1, c) == 1)
        {
         h_high[live_idx]  = h[0];
         h_low[live_idx]   = l[0];
         h_close[live_idx] = c[0];

         // Incremental recalculation on the live HTF index (O(1) tick performance)
         // Passed g_htf_count as prev_calculated to preserve state safety
         g_calc.Calculate(g_htf_count, g_htf_count, h_high, h_low, h_close, h_res_dur, h_res_col, InpShowSOT);
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
            BufWaveDur[i] = h_res_dur[idx_htf];
            BufColors[i]  = h_res_col[idx_htf];
           }
         else
           {
            BufWaveDur[i] = EMPTY_VALUE;
            BufColors[i]  = 0.0;
           }
        }
      else
        {
         BufWaveDur[i] = EMPTY_VALUE;
         BufColors[i]  = 0.0;
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
      int required_bars = InpATRPeriod + 5;
      if(EnsureHTFDataReady(_Symbol, InpTimeframe, required_bars))
        {
         g_data_synced = true;
         ChartRedraw(); // Force MT5 to invoke OnCalculate
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
