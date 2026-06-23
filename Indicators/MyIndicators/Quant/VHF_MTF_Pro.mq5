//+------------------------------------------------------------------+
//|                                                  VHF_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.20" // Optimized with Forming LTF Block Flat-Force, OnTimer Guard and Heikin Ashi support
#property description "Vertical Horizontal Filter (Multi-Timeframe)."
#property description "Displays HTF Trend Intensity on current chart cleanly without live-bar warping."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Levels
#property indicator_level1 0.3
#property indicator_level2 0.4
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot: VHF Line
#property indicator_label1  "VHF MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrDodgerBlue, clrGold
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\VHF_Calculator.mqh>

//--- Input Parameters
input ENUM_TIMEFRAMES           InpTimeframe   = PERIOD_H1;           // Target Higher Timeframe
input int                       InpPeriod      = 28;                  // VHF Period
input ENUM_VHF_MODE             InpMode        = VHF_MODE_CLOSE_ONLY; // VHF Search Mode
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;     // Applied Price

//--- Buffers (Visual)
double BufVHF[];
double BufColor[];

//--- Internal HTF Data Caches
double h_vhf[]; // Calculated VHF on HTF
datetime h_time[]; // HTF Time index
double h_open[], h_high[], h_low[], h_close[];

//--- Global HTF State Tracking
CVHFCalculator *g_calc;
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

// Validate Timeframe
   if(InpTimeframe <= Period() && InpTimeframe != PERIOD_CURRENT)
     {
      Print("Warning: Target Timeframe should be > Current Timeframe for MTF mode.");
     }

   SetIndexBuffer(0, BufVHF,   INDICATOR_DATA);
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(BufVHF,   false);
   ArraySetAsSeries(BufColor, false);

//--- Configure dynamic calculator based on price source (Heikin Ashi support)
   bool use_ha = (InpSourcePrice <= PRICE_HA_CLOSE);
   if(use_ha)
      g_calc = new CVHFCalculator_HA();
   else
      g_calc = new CVHFCalculator();

   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpPeriod, InpMode))
      return INIT_FAILED;

   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string name = StringFormat("VHF MTF %s(%d%s)", tf_name, InpPeriod, (use_ha ? " HA" : ""));
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

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
      ArrayResize(h_vhf,   g_htf_count);

      if(CopyTime(_Symbol,  InpTimeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  InpTimeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  InpTimeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   InpTimeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, InpTimeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      //--- Calculate VHF on HTF (Closed bars and forming bar initialized)
      g_calc.Calculate(g_htf_count, 0, price_type, h_open, h_high, h_low, h_close, h_vhf);

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

         // Incremental recalculation on the live HTF index (O(1) tick performance)
         g_calc.Calculate(g_htf_count, live_idx, price_type, h_open, h_high, h_low, h_close, h_vhf);
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
            double val = h_vhf[idx_htf];
            BufVHF[i] = val;

            // Color Logic (Chop, Trending, Strong Trend)
            if(val > 0.40)
               BufColor[i] = 2.0; // Index 2: Gold (Strong Trend)
            else
               if(val > 0.30)
                  BufColor[i] = 1.0; // Index 1: DodgerBlue (Trend Start / Moderate)
               else
                  BufColor[i] = 0.0; // Index 0: Gray (Neutral / Chop Range)
           }
         else
           {
            BufVHF[i]   = EMPTY_VALUE;
            BufColor[i] = 0.0;
           }
        }
      else
        {
         BufVHF[i]   = EMPTY_VALUE;
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
