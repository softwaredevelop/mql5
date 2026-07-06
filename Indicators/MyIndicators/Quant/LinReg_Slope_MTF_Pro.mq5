//+------------------------------------------------------------------+
//|                                         LinReg_Slope_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Upgraded with dynamic 5-Zone hybrid R2-based thermal color matrix (Standard aligned)
#property description "Multi-Timeframe (MTF) Linear Regression Slope."
#property description "Displays HTF Linear Regression Slope on current chart cleanly without live-bar warping."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Plot 1: Slope Histogram (Swapped Bull/Bear Thermal Palette)
#property indicator_label1  "Slope MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors:
// 0 = Chop/Noise (Gray)
// 1 = Bull Climax / Strong (MediumSeaGreen)
// 2 = Bull Flow / Weak (PaleGreen)
// 3 = Bear Climax / Strong (Crimson)
// 4 = Bear Flow / Weak (LightCoral)
#property indicator_color1  clrGray, clrMediumSeaGreen, clrPaleGreen, clrCrimson, clrLightCoral
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\LinearRegression_Calculator.mqh>

enum ENUM_CANDLE_SOURCE
  {
   SOURCE_STANDARD,
   SOURCE_HEIKIN_ASHI
  };

//--- Input Parameters ---
input group "Timeframe Settings"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_H1;        // Target Higher Timeframe

input group                     "Slope Settings"
input int                InpPeriod       = 20;              // Observation Period (N)
input ENUM_CANDLE_SOURCE InpSource       = SOURCE_STANDARD;  // Candle Source
input ENUM_APPLIED_PRICE InpPrice        = PRICE_CLOSE;     // Applied Price (Standard)
input double             InpTrendLevel   = 0.7;             // Strong Trend Level (R2 Threshold)

//--- Buffers
double    BufferSlope_MTF[];
double    BufferColors_MTF[];

//--- Internal HTF Data Caches
double    h_res_slope[]; // HTF Slope Results cached
double    h_res_r2[];    // HTF R2 Results cached
double    h_res_f[];     // HTF Forecast Results cached
datetime  h_time[];      // HTF Time index
double    h_open[], h_high[], h_low[], h_close[]; // HTF Price Data

//--- Global variables ---
CLinearRegressionCalculator *g_calculator;
bool                         g_is_mtf_mode         = false;
ENUM_TIMEFRAMES              g_calc_timeframe;
bool                         g_data_ready          = false;
bool                     g_data_synced         = false;
int                          g_htf_count           = 0;
datetime                     g_last_htf_time       = 0;

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
   g_calc_timeframe = InpTimeframe;
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
   SetIndexBuffer(0, BufferSlope_MTF,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferColors_MTF, INDICATOR_COLOR_INDEX);
   ArraySetAsSeries(BufferSlope_MTF,  false);
   ArraySetAsSeries(BufferColors_MTF, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- 3. Initialize Calculator (Factory Logic)
   bool use_ha = (InpSource == SOURCE_HEIKIN_ASHI);
   if(use_ha)
      g_calculator = new CLinearRegressionCalculator_HA();
   else
      g_calculator = new CLinearRegressionCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod))
     {
      Print("Failed to create or initialize Linear Regression Calculator object.");
      return(INIT_FAILED);
     }

//--- 4. Set Shortname
   string type = use_ha ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" " + EnumToString(g_calc_timeframe)) : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("LinReg Slope%s%s(%d)", type, tf_str, InpPeriod));

// Draw begin logic
   int draw_begin = InpPeriod;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);

//--- Set dynamic decimal digits to match symbol precision + 2 (EURUSD = 7 digits) to show micro-pip details
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 2);

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
      double s[], r2[], f[];
      ArrayResize(s, rates_total);
      ArrayResize(r2, rates_total);
      ArrayResize(f, rates_total);

      g_calculator.CalculateState(rates_total, prev_calculated, open, high, low, close, InpPrice, s, r2, f);

      int start_index = (prev_calculated > 0) ? prev_calculated - 1 : InpPeriod;
      for(int i = start_index; i < rates_total; i++)
        {
         double r  = r2[i];
         double sl = s[i];
         BufferSlope_MTF[i] = sl;

         if(r <= 0.3)
           {
            BufferColors_MTF[i] = 0.0; // Gray
           }
         else
            if(sl >= 0.0)
              {
               if(r >= InpTrendLevel)
                  BufferColors_MTF[i] = 1.0; // Strong Bullish
               else
                  BufferColors_MTF[i] = 2.0; // Weak Bullish
              }
            else // sl < 0.0
              {
               if(r >= InpTrendLevel)
                  BufferColors_MTF[i] = 3.0; // Strong Bearish
               else
                  BufferColors_MTF[i] = 4.0; // Weak Bearish
              }
        }
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

      ArrayResize(h_res_slope, g_htf_count);
      ArrayResize(h_res_r2,     g_htf_count);
      ArrayResize(h_res_f,      g_htf_count);

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

      //--- Calculate Slope states on HTF (Closed bars and forming bar initialized)
      g_calculator.CalculateState(g_htf_count, 0, h_open, h_high, h_low, h_close, InpPrice, h_res_slope, h_res_r2, h_res_f);

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
         g_calculator.CalculateState(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, InpPrice, h_res_slope, h_res_r2, h_res_f);
        }
     }

//--- 3. FIXED: Dynamically adjust 'start' to the beginning of the current forming HTF bar
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
            double r2 = h_res_r2[idx_htf];
            double sl = h_res_slope[idx_htf];
            BufferSlope_MTF[i] = sl;

            // Color Logic based on HTF direction and HTF R2 strength
            if(r2 <= 0.3)
              {
               BufferColors_MTF[i] = 0.0; // Index 0: Gray (Chop)
              }
            else
               if(sl >= 0.0)
                 {
                  if(r2 >= InpTrendLevel)
                     BufferColors_MTF[i] = 1.0; // Index 1: MediumSeaGreen (Strong Bull)
                  else
                     BufferColors_MTF[i] = 2.0; // Index 2: PaleGreen (Weak Bull)
                 }
               else
                 {
                  if(r2 >= InpTrendLevel)
                     BufferColors_MTF[i] = 3.0; // Index 3: Crimson (Strong Bear)
                  else
                     BufferColors_MTF[i] = 4.0; // Index 4: LightCoral (Weak Bear)
                 }
           }
         else
           {
            BufferSlope_MTF[i]  = EMPTY_VALUE;
            BufferColors_MTF[i] = 0.0;
           }
        }
      else
        {
         BufferSlope_MTF[i]  = EMPTY_VALUE;
         BufferColors_MTF[i] = 0.0;
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
