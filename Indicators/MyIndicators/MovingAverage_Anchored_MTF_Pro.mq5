//+------------------------------------------------------------------+
//|                                   MovingAverage_Anchored_MTF_Pro |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.11" // Declared missing long h_vol[] cache array and fully resolved all 18 parameter matching errors
#property description "Multi-Timeframe (MTF) Universal Anchored Moving Average."
#property description "Displays HTF Anchored MA segments cleanly directly on lower TF charts without live-bar warping or connecting line drag."

#property indicator_chart_window
#property indicator_buffers 2 // Two buffers for gapped drawing
#property indicator_plots   2

//--- Plot 1: MA Line (Odd Periods)
#property indicator_label1  "MA Anch MTF"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: MA Line (Even Periods)
#property indicator_label2  "MA Anch MTF (Segment)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#include <MyIncludes\MovingAverage_Anchored_Engine.mqh>

//--- Input Parameters ---
input group "Timeframe Settings"
input ENUM_TIMEFRAMES           InpUpperTimeframe = PERIOD_H1; // Target Timeframe

input group "MA Settings"
input int                       InpPeriod      = 20;              // Smoothing Period
input ENUM_MA_TYPE              InpMAType      = SMA;             // MA Type
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD; // Price Source

input group "Anchor Settings"
input ENUM_ANCHOR_PERIOD        InpAnchor      = ANCHOR_SESSION;  // Reset Anchor Period
input string                    InpCustomStart = "09:00";   // Custom Session Start (HH:MM)
input string                    InpCustomEnd   = "18:00";   // Custom Session End (HH:MM)

//--- Indicator Buffers ---
double    BufferMA_Odd_MTF[];
double    BufferMA_Even_MTF[];

//--- Internal HTF Data Caches
double    h_res_odd[];   // HTF Odd Results cached
double    h_res_even[];  // HTF Even Results cached
datetime  h_time[];      // HTF Time index
double    h_open[], h_high[], h_low[], h_close[]; // HTF Price Data
long      h_vol[];       // FIXED: Declared missing global HTF volume cache array

//--- Global variables ---
CMovingAverageAnchoredCalculator *g_calculator;
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
   g_last_htf_time = 0;
   g_htf_count = 0;

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
   SetIndexBuffer(0, BufferMA_Odd_MTF,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferMA_Even_MTF, INDICATOR_DATA);
   ArraySetAsSeries(BufferMA_Odd_MTF,  false);
   ArraySetAsSeries(BufferMA_Even_MTF, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- 3. Initialize Calculator
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMovingAverageAnchoredCalculator_HA();
   else
      g_calculator = new CMovingAverageAnchoredCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriod, InpMAType, InpAnchor, InpCustomStart, InpCustomEnd))
     {
      Print("Failed to initialize Moving Average Anchored Calculator object.");
      return(INIT_FAILED);
     }

//--- 4. Set Shortname
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" " + EnumToString(g_calc_timeframe)) : "";
   string ma_name = EnumToString(InpMAType);
   StringToUpper(ma_name);
   string anchor_name = EnumToString(InpAnchor);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MA Anch%s%s(%s,%s,%d)", type, tf_str, ma_name, StringSubstr(anchor_name, 7), InpPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// Draw begin logic
   int draw_begin = InpPeriod;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);

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

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

//================================================================
// MODE 1: Current Timeframe (Standard)
//================================================================
   if(!g_is_mtf_mode)
     {
      // Force standard chronological indexing for state-safety
      ArraySetAsSeries(time, false);
      ArraySetAsSeries(open, false);
      ArraySetAsSeries(high, false);
      ArraySetAsSeries(low, false);
      ArraySetAsSeries(close, false);

      // Determine best volume array (Use Real Volume if available, otherwise fallback to Tick Volume)
      long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

      if(volume_limit > 0)
         g_calculator.Calculate(rates_total, prev_calculated, price_type, time, open, high, low, close, volume, BufferMA_Odd_MTF, BufferMA_Even_MTF);
      else
         g_calculator.Calculate(rates_total, prev_calculated, price_type, time, open, high, low, close, tick_volume, BufferMA_Odd_MTF, BufferMA_Even_MTF);

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

//--- Determine best volume array (Use Real Volume if available, otherwise fallback to Tick Volume)
   long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

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
      ArrayResize(h_vol,   g_htf_count); // FIXED: Resized newly declared h_vol cache buffer

      ArrayResize(h_res_odd,  g_htf_count);
      ArrayResize(h_res_even, g_htf_count);

      if(CopyTime(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   g_calc_timeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, g_calc_timeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      // High-Performance dynamic volume routing on the HTF Timeline
      int copied_vol = 0;
      if(volume_limit > 0)
         copied_vol = CopyRealVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, h_vol);
      else
         copied_vol = CopyTickVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, h_vol);

      if(copied_vol != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      // Force chronological array alignment for calculations
      ArraySetAsSeries(h_time, false);
      ArraySetAsSeries(h_open, false);
      ArraySetAsSeries(h_high, false);
      ArraySetAsSeries(h_low, false);
      ArraySetAsSeries(h_close, false);

      //--- Calculate KAMA on HTF (Closed bars and forming bar initialized) (FIXED: Passed h_vol to match overloaded 11-param signature)
      g_calculator.Calculate(g_htf_count, 0, price_type, h_time, h_open, h_high, h_low, h_close, h_vol, h_res_odd, h_res_even);

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 2. Live Update for the Current Forming HTF Bar (Index: g_htf_count - 1) on every tick!
   int live_idx = g_htf_count - 1;
   if(live_idx >= InpPeriod)
     {
      double o[1], h[1], l[1], c[1];
      datetime t[1];
      long vol[1];
      int shift = iBarShift(_Symbol, g_calc_timeframe, htf_time_current, false);
      if(shift >= 0 &&
         CopyTime(_Symbol,   g_calc_timeframe, shift, 1, t) == 1 &&
         CopyOpen(_Symbol,   g_calc_timeframe, shift, 1, o) == 1 &&
         CopyHigh(_Symbol,   g_calc_timeframe, shift, 1, h) == 1 &&
         CopyLow(_Symbol,    g_calc_timeframe, shift, 1, l) == 1 &&
         CopyClose(_Symbol,  g_calc_timeframe, shift, 1, c) == 1)
        {
         h_time[live_idx]  = t[0];
         h_open[live_idx]  = o[0];
         h_high[live_idx]  = h[0];
         h_low[live_idx]   = l[0];
         h_close[live_idx] = c[0];

         // Copy live volume dynamically
         int copied = 0;
         if(volume_limit > 0)
            copied = CopyRealVolume(_Symbol, g_calc_timeframe, shift, 1, vol);
         else
            copied = CopyTickVolume(_Symbol, g_calc_timeframe, shift, 1, vol);

         if(copied == 1)
           {
            h_vol[live_idx] = vol[0];
           }

         // Incremental recalculation on the live HTF index in O(1)
         // Passed g_htf_count as prev_calculated to preserve state safety (Double accumulation preventer) (FIXED: Passed h_vol to match overloaded 11-param signature)
         g_calculator.Calculate(g_htf_count, g_htf_count, price_type, h_time, h_open, h_high, h_low, h_close, h_vol, h_res_odd, h_res_even);
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
      datetime t_val = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t_val, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufferMA_Odd_MTF[i]  = h_res_odd[idx_htf];
            BufferMA_Even_MTF[i] = h_res_even[idx_htf];
           }
         else
           {
            BufferMA_Odd_MTF[i]  = EMPTY_VALUE;
            BufferMA_Even_MTF[i] = EMPTY_VALUE;
           }
        }
      else
        {
         BufferMA_Odd_MTF[i]  = EMPTY_VALUE;
         BufferMA_Even_MTF[i] = EMPTY_VALUE;
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
//+------------------------------------------------------------------+
