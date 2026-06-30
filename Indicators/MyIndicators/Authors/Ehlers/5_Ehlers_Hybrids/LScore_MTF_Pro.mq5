//+------------------------------------------------------------------+
//|                                                 LScore_MTF_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Upgraded with 3-digit Gamma precision to support precise Fibonacci parameters
#property description "Multi-Timeframe (MTF) Statistical Laguerre Z-Score (L-Score) Oscillator."
#property description "Displays HTF Laguerre deviations cleanly directly on lower TF charts without live-bar warping."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

//--- Plot 1: L-Score Histogram (Swapped Bull/Bear Thermal Palette)
#property indicator_label1  "L-Score MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Swapped Palette:
// 0: Noise/Neutral     (Gray)
// 1: Bullish Flow      (LightSkyBlue)
// 2: Bullish Climax    (DeepSkyBlue)
// 3: Bearish Flow      (Coral)
// 4: Bearish Climax    (OrangeRed)
#property indicator_color1  clrGray, clrLightSkyBlue, clrDeepSkyBlue, clrCoral, clrOrangeRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Optional Signal Line (Wyckoff Reversal Trigger)
#property indicator_label2  "Signal MTF"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrFireBrick
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\LScore_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Input Parameters ---
input group "Timeframe Settings"
input ENUM_TIMEFRAMES           InpTimeframe   = PERIOD_H1;       // Target Higher Timeframe

input group "Laguerre Baseline Settings"
input double                    InpGamma       = 0.5;         // Laguerre Gamma (0.0 to 1.0, e.g. 0.236, 0.382)
input ENUM_APPLIED_PRICE_HA_ALL InpPrice       = PRICE_CLOSE_STD; // Price Source

input group "Volatility Settings"
input int                       InpPeriod      = 20;          // Sigma Lookback Period (N)

input group "Signal Line Settings"
input bool                      InpShowSignal  = true;        // Show Signal Line?
input int                       InpSignalPeriod= 5;           // Signal Line Period
input ENUM_MA_TYPE              InpSignalType  = SMA;         // Signal Line MA Type

input group "Indicator Levels"
input double                    InpLevelFlowHigh   = 2.0;         // High Warning Level (Bullish Flow)
input double                    InpLevelFlowLow    = -2.0;        // Low Warning Level (Bearish Flow)
input double                    InpLevelClimaxHigh = 2.5;         // High Climax Level (Bullish Climax)
input double                    InpLevelClimaxLow  = -2.5;        // Low Climax Level (Bearish Climax)
input double                    InpLevelExtremeHigh= 3.0;         // High Exhaustion Level
input double                    InpLevelExtremeLow = -3.0;        // Low Exhaustion Level
input color                     InpLevelColor      = clrSilver;   // Levels Color
input ENUM_LINE_STYLE           InpLevelStyle      = STYLE_DOT;   // Levels Style

//--- Buffers ---
double BufferL_MTF[];
double BufferColors_MTF[];
double BufferSignal_MTF[];

//--- Internal HTF Data Caches
double h_res[], h_sig[]; // HTF Results cached
datetime h_time[];
double h_open[], h_high[], h_low[], h_close[];
long   h_vol[]; // HTF raw volume cache
double h_vol_double[]; // HTF volume cast to double to support VWMA Signal line

//--- Volume Cache to support Volume-Weighted types (VWMA) on current timeframe
double g_double_volume[];

//--- Global HTF State Tracking
CLScoreCalculator        *g_calculator;
CMovingAverageCalculator *g_signal_calculator;
datetime                 g_last_htf_time     = 0;
int                      g_htf_count         = 0;
bool                     g_data_ready        = false;
bool                     g_data_synced       = false;

bool                     g_is_mtf_mode         = false;
ENUM_TIMEFRAMES          g_calc_timeframe;

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
   SetIndexBuffer(0, BufferL_MTF,      INDICATOR_DATA);
   SetIndexBuffer(1, BufferColors_MTF, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferSignal_MTF, INDICATOR_DATA);

   ArraySetAsSeries(BufferL_MTF,      false);
   ArraySetAsSeries(BufferColors_MTF, false);
   ArraySetAsSeries(BufferSignal_MTF, false);

//--- 3. Dynamically configure horizontal levels to support custom input parameters
   IndicatorSetInteger(INDICATOR_LEVELS, 6);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpLevelFlowHigh);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpLevelFlowLow);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, InpLevelClimaxHigh);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, InpLevelClimaxLow);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 4, InpLevelExtremeHigh);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 5, InpLevelExtremeLow);

   IndicatorSetInteger(INDICATOR_LEVELCOLOR, InpLevelColor);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, InpLevelStyle);

//--- 4. Initialize Calculators
   bool is_ha = (InpPrice <= PRICE_HA_CLOSE);
   g_calculator = new CLScoreCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpGamma, InpPeriod, is_ha))
     {
      Print("Failed to initialize L-Score Calculator.");
      return(INIT_FAILED);
     }

   if(InpShowSignal)
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetString(1, PLOT_LABEL, "Signal MTF");

      g_signal_calculator = new CMovingAverageCalculator();
      if(CheckPointer(g_signal_calculator) == POINTER_INVALID || !g_signal_calculator.Init(InpSignalPeriod, InpSignalType))
        {
         Print("Failed to initialize Signal Line Calculator.");
         return(INIT_FAILED);
        }
     }
   else
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetString(1, PLOT_LABEL, NULL);
     }

//--- 5. Set Shortname - Updated format string to %.3f to support exact Fibonacci decimals
   string type = (InpPrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" " + EnumToString(g_calc_timeframe)) : "";
   string short_name = "";

   if(InpShowSignal)
     {
      string sig_name = EnumToString(InpSignalType);
      StringToUpper(sig_name);
      short_name = StringFormat("LScore%s%s(%.3f,%d) %s(%d)", type, tf_str, InpGamma, InpPeriod, sig_name, InpSignalPeriod);
     }
   else
     {
      short_name = StringFormat("LScore%s%s(%.3f,%d)", type, tf_str, InpGamma, InpPeriod);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "L-Score MTF");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

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
   if(CheckPointer(g_signal_calculator) != POINTER_INVALID)
      delete g_signal_calculator;
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

   ENUM_APPLIED_PRICE price_type = (InpPrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpPrice) :
                                   (ENUM_APPLIED_PRICE)InpPrice;

//================================================================
// MODE 1: Current Timeframe (Standard)
//================================================================
   if(!g_is_mtf_mode)
     {
      // Determine best volume array (Use Real Volume if available, otherwise fallback to Tick Volume)
      long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

      ArrayResize(g_double_volume, rates_total);
      int start_sync = (prev_calculated > 0) ? prev_calculated - 1 : 0;

      if(volume_limit > 0)
        {
         for(int i = start_sync; i < rates_total; i++)
            g_double_volume[i] = (double)volume[i];
        }
      else
        {
         for(int i = start_sync; i < rates_total; i++)
            g_double_volume[i] = (double)tick_volume[i];
        }

      // Calculate L-Score
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferL_MTF);

      // Calculate Signal Line
      if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
        {
         g_signal_calculator.CalculateOnArray(rates_total, prev_calculated, BufferL_MTF, g_double_volume, BufferSignal_MTF, InpPeriod - 1);
        }

      // Apply 5-Zone Swapped Thermal Coloring Logic
      int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      for(int i = start_index; i < rates_total; i++)
        {
         double l_val = BufferL_MTF[i];

         if(l_val > InpLevelClimaxHigh)
            BufferColors_MTF[i] = 2.0;
         else
            if(l_val > InpLevelFlowHigh)
               BufferColors_MTF[i] = 1.0;
            else
               if(l_val < InpLevelClimaxLow)
                  BufferColors_MTF[i] = 4.0;
               else
                  if(l_val < InpLevelFlowLow)
                     BufferColors_MTF[i] = 3.0;
                  else
                     BufferColors_MTF[i] = 0.0;
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

      ArrayResize(h_time,       g_htf_count);
      ArrayResize(h_open,       g_htf_count);
      ArrayResize(h_high,       g_htf_count);
      ArrayResize(h_low,        g_htf_count);
      ArrayResize(h_close,      g_htf_count);
      ArrayResize(h_vol,        g_htf_count);
      ArrayResize(h_vol_double, g_htf_count);

      ArrayResize(h_res,        g_htf_count);
      ArrayResize(h_sig,        g_htf_count);

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

      // Convert HTF volume cache to double precision
      for(int j = 0; j < g_htf_count; j++)
         h_vol_double[j] = (double)h_vol[j];

      // Force chronological array alignment for calculations
      ArraySetAsSeries(h_time, false);
      ArraySetAsSeries(h_open, false);
      ArraySetAsSeries(h_high, false);
      ArraySetAsSeries(h_low, false);
      ArraySetAsSeries(h_close, false);
      ArraySetAsSeries(h_vol, false);

      //--- Calculate HTF L-Score (Closed bars and forming bar initialized)
      g_calculator.Calculate(g_htf_count, 0, price_type, h_open, h_high, h_low, h_close, h_res);

      //--- Calculate HTF Signal Line
      if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
        {
         g_signal_calculator.CalculateOnArray(g_htf_count, 0, h_res, h_vol_double, h_sig, InpPeriod - 1);
        }

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 2. Live Update for the Current Forming HTF Bar (Index: g_htf_count - 1) on every tick!
   int live_idx = g_htf_count - 1;
   if(live_idx >= InpPeriod)
     {
      double o[1], h[1], l[1], c[1];
      long vol[1];
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

         // Copy live volume dynamically
         int copied = 0;
         if(volume_limit > 0)
            copied = CopyRealVolume(_Symbol, g_calc_timeframe, shift, 1, vol);
         else
            copied = CopyTickVolume(_Symbol, g_calc_timeframe, shift, 1, vol);

         if(copied == 1)
           {
            h_vol[live_idx] = vol[0];
            h_vol_double[live_idx] = (double)vol[0];
           }

         // Incremental recalculation on the live HTF index in O(1)
         g_calculator.Calculate(g_htf_count, g_htf_count, price_type, h_open, h_high, h_low, h_close, h_res);

         // Recalculate Signal Line on HTF live index
         if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
           {
            g_signal_calculator.CalculateOnArray(g_htf_count, g_htf_count, h_res, h_vol_double, h_sig, InpPeriod - 1);
           }
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
            double l_val = h_res[idx_htf];

            BufferL_MTF[i] = l_val;

            if(InpShowSignal)
               BufferSignal_MTF[i] = h_sig[idx_htf];
            else
               BufferSignal_MTF[i] = EMPTY_VALUE;

            if(l_val >= InpLevelClimaxHigh)
               BufferColors_MTF[i] = 2.0;
            else
               if(l_val >= InpLevelFlowHigh)
                  BufferColors_MTF[i] = 1.0;
               else
                  if(l_val <= InpLevelClimaxLow)
                     BufferColors_MTF[i] = 4.0;
                  else
                     if(l_val <= InpLevelFlowLow)
                        BufferColors_MTF[i] = 3.0;
                     else
                        BufferColors_MTF[i] = 0.0;
           }
         else
           {
            BufferL_MTF[i]      = EMPTY_VALUE;
            BufferSignal_MTF[i] = EMPTY_VALUE;
            BufferColors_MTF[i] = 0.0;
           }
        }
      else
        {
         BufferL_MTF[i]      = EMPTY_VALUE;
         BufferSignal_MTF[i] = EMPTY_VALUE;
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
