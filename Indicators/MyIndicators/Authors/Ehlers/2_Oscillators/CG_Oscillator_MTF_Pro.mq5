//+------------------------------------------------------------------+
//|                                        CG_Oscillator_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Fixed indicator decimal digits rounding bug to restore high-resolution Data Window visibility
#property description "Multi-Timeframe (MTF) John Ehlers' Center of Gravity (CG) Oscillator."
#property description "Displays HTF Center of Gravity cleanly on current chart without live-bar warping."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: CG Line MTF
#property indicator_label1  "CG MTF"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Signal Line MTF
#property indicator_label2  "Signal MTF"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\CG_Oscillator_Calculator.mqh>

enum ENUM_CANDLE_SOURCE
  {
   SOURCE_STANDARD,
   SOURCE_HEIKIN_ASHI
  };

//--- Input Parameters ---
input group "Timeframe Settings"
input ENUM_TIMEFRAMES           InpUpperTimeframe = PERIOD_H1;     // Target Higher Timeframe

input group                     "CG Settings"
input int                InpPeriod       = 10;               // Observation Period (N)
input ENUM_CANDLE_SOURCE InpSource       = SOURCE_STANDARD;  // Candle Source
input bool               InpOriginalMode = true;             // True = Ehlers' Raw (Negative), False = Center around 0.0

//--- Buffers
double    BufferCG_MTF[];
double    BufferSignal_MTF[];

//--- Internal HTF Data Caches
double    h_res_cg[];    // HTF CG Results cached
double    h_res_sig[];   // HTF Signal Results cached
datetime  h_time[];      // HTF Time index
double    h_open[], h_high[], h_low[], h_close[]; // HTF Price Data

//--- Global variables ---
CCGOscillatorCalculator *g_calculator;
bool                     g_is_mtf_mode         = false;
ENUM_TIMEFRAMES          g_calc_timeframe;
bool                     g_data_ready          = false;
bool                     g_data_synced         = false;
int                      g_htf_count           = 0;
datetime                 g_last_htf_time       = 0;

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
   g_htf_count = 0;
   g_last_htf_time = 0;

//--- 1. Resolve Timeframe
   g_calc_timeframe = InpUpperTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      PrintFormat("Error: Target timeframe (%s) must be >= current timeframe (%s).",
                  EnumToString(g_calc_timeframe), EnumToString(Period()));
      return(INIT_FAILED);
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

//--- 2. Setup Buffers
   SetIndexBuffer(0, BufferCG_MTF,     INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal_MTF,  INDICATOR_DATA);
   ArraySetAsSeries(BufferCG_MTF,     false);
   ArraySetAsSeries(BufferSignal_MTF,    false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- 3. Dynamically configure horizontal centerline levels
   double center_level = InpOriginalMode ? -(InpPeriod + 1) / 2.0 : 0.0;
   IndicatorSetInteger(INDICATOR_LEVELS, 1);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, center_level);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, STYLE_DOT);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, clrSilver);

//--- 4. Initialize Calculator
   if(InpSource == SOURCE_HEIKIN_ASHI)
      g_calculator = new CCGOscillatorCalculator_HA();
   else
      g_calculator = new CCGOscillatorCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpOriginalMode))
     {
      Print("Failed to create or initialize CG Oscillator Calculator object.");
      return(INIT_FAILED);
     }

//--- 5. Set Shortname
   string type = (InpSource == SOURCE_HEIKIN_ASHI) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" " + EnumToString(g_calc_timeframe)) : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CG%s%s(%d)%s", type, tf_str, InpPeriod, InpOriginalMode ? " Orig" : " Pro"));

// Draw begin logic
   int draw_begin = InpPeriod;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin + 1);

//--- FIXED: Set dynamic decimal digits to match symbol precision instead of hardcoded 2
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

//--- Initialize 1-second timer for weekend/async chart refreshes (Only if MTF mode is active)
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
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
   if(rates_total < 2)
      return(0);

   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return(0);

//--- Force strict chronological indexing for state-safety on input price arrays
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

   ENUM_APPLIED_PRICE price_type = (InpSource == SOURCE_HEIKIN_ASHI) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSource) :
                                   (ENUM_APPLIED_PRICE)InpSource;

//================================================================
// MODE 1: Current Timeframe (Standard)
//================================================================
   if(!g_is_mtf_mode)
     {
      g_calculator.Calculate(rates_total, prev_calculated, PRICE_MEDIAN, open, high, low, close, BufferCG_MTF, BufferSignal_MTF);
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

      ArrayResize(h_time,  g_htf_count);
      ArrayResize(h_open,  g_htf_count);
      ArrayResize(h_high,  g_htf_count);
      ArrayResize(h_low,   g_htf_count);
      ArrayResize(h_close, g_htf_count);

      ArrayResize(h_res_cg,  g_htf_count);
      ArrayResize(h_res_sig, g_htf_count);

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

      //--- Calculate CG on HTF (Closed bars and forming bar initialized)
      g_calculator.Calculate(g_htf_count, 0, PRICE_MEDIAN, h_open, h_high, h_low, h_close, h_res_cg, h_res_sig);

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
         g_calculator.Calculate(g_htf_count, g_htf_count, PRICE_MEDIAN, h_open, h_high, h_low, h_close, h_res_cg, h_res_sig);
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
            BufferCG_MTF[i]     = h_res_cg[idx_htf];
            BufferSignal_MTF[i] = h_res_sig[idx_htf];
           }
         else
           {
            BufferCG_MTF[i]     = EMPTY_VALUE;
            BufferSignal_MTF[i] = EMPTY_VALUE;
           }
        }
      else
        {
         BufferCG_MTF[i]     = EMPTY_VALUE;
         BufferSignal_MTF[i] = EMPTY_VALUE;
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
