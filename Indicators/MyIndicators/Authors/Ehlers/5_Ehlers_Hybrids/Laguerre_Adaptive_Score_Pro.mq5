//+------------------------------------------------------------------+
//|                                    Laguerre_Adaptive_Score_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Refactored file and class references from LScore to Score
#property description "Statistical Adaptive Laguerre Z-Score (Adaptive Score) Oscillator."
#property description "Measures distance of price from the Adaptive Laguerre Filter in Sigma units."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

//--- Plot 1: Adaptive Score Histogram (Swapped Thermal Palette)
#property indicator_label1  "Adaptive Score"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Palette Configuration: 0=Neutral/Gray, 1=Bull Flow, 2=Bull Climax, 3=Bear Flow, 4=Bear Climax
#property indicator_color1  clrGray, clrLightSkyBlue, clrDeepSkyBlue, clrCoral, clrOrangeRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Dynamic Signal Line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrFireBrick
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\Laguerre_Adaptive_Score_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\DataSync_Tools.mqh> // Centralized MTF synchronization daemon

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;       // Target Higher Timeframe

input group "--- Adaptive Baseline Settings ---"
input ENUM_ADAPTIVE_METHOD      InpAdaptiveMethod = METHOD_EFFICIENCY_RATIO; // Adaptive Engine Method
input int                       InpAdaptivePeriod = 10;                  // Volatility/ER/StDev Period
input double                    InpGammaMin       = 0.136;               // Minimum Gamma (Max Speed)
input double                    InpGammaMax       = 0.882;               // Maximum Gamma (Max Smooth)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice     = PRICE_CLOSE_STD;     // Price Source

input group "--- Volatility Settings ---"
input int                       InpPeriod         = 20;                  // Sigma Lookback Period (N)

input group "--- Signal Line Settings ---"
input bool                      InpShowSignal     = true;                // Show Signal Line?
input int                       InpSignalPeriod   = 5;                   // Signal Period
input ENUM_MA_TYPE              InpSignalType     = SMA;                 // Signal MA Type (Supports VWMA)

input group "--- Indicator Levels ---"
input double                    InpLevelFlowHigh   = 1.5;         // High Warning Level (Bullish Flow)
input double                    InpLevelFlowLow    = -1.5;        // Low Warning Level (Bearish Flow)
input double                    InpLevelClimaxHigh = 2.0;         // High Climax Level (Bullish Climax)
input double                    InpLevelClimaxLow  = -2.0;        // Low Climax Level (Bearish Climax)
input double                    InpLevelExtremeHigh= 2.5;         // High Exhaustion Level
input double                    InpLevelExtremeLow = -2.5;        // Low Exhaustion Level
input color                     InpLevelColor      = clrSilver;   // Levels Color
input ENUM_LINE_STYLE           InpLevelStyle      = STYLE_DOT;   // Levels Style

//--- Visual Indicator Buffers ---
double    BufferScore[];
double    BufferColors[];
double    BufferSignal[];

//--- Volume Cache (Used on Current Timeframe Mode)
double    g_double_volume[];

//--- Internal HTF Data Caches
double    h_open[], h_high[], h_low[], h_close[], h_volume[];
double    h_res_score[], h_res_color[], h_res_signal[];
datetime  h_time[];

//--- Global Objects & Synchronizer State
CLaguerreAdaptiveScoreCalculator *g_calculator;
CMovingAverageCalculator         *g_signal_calculator;

bool            g_is_mtf_mode         = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready          = false;
bool            g_data_synced         = false;
int             g_htf_count           = 0;
datetime        g_last_htf_time       = 0;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready    = false;
   g_data_synced   = false;
   g_htf_count     = 0;
   g_last_htf_time = 0;

//--- 1. Resolve Timeframe and validate direction
   g_calc_timeframe = InpTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      PrintFormat("Critical Error: Target timeframe (%s) must be >= current timeframe (%s).",
                  EnumToString(g_calc_timeframe), EnumToString(Period()));
      return(INIT_FAILED);
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

//--- 2. Bind buffers to index mapping
   SetIndexBuffer(0, BufferScore,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferSignal, INDICATOR_DATA);

//--- Force strict chronological alignment (false = old to new)
   ArraySetAsSeries(BufferScore,  false);
   ArraySetAsSeries(BufferColors, false);
   ArraySetAsSeries(BufferSignal, false);

//--- Setup EMPTY_VALUE fallback for signal line
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- 3. Dynamically configure horizontal levels to support custom inputs
   IndicatorSetInteger(INDICATOR_LEVELS, 6);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpLevelFlowHigh);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpLevelFlowLow);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, InpLevelClimaxHigh);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, InpLevelClimaxLow);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 4, InpLevelExtremeHigh);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 5, InpLevelExtremeLow);

   IndicatorSetInteger(INDICATOR_LEVELCOLOR, InpLevelColor);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, InpLevelStyle);

   bool is_ha = (InpSourcePrice <= PRICE_HA_CLOSE);

//--- 4. Initialize Physical Adaptive Score Calculator
   if(is_ha)
      g_calculator = new CLaguerreAdaptiveScoreCalculator_HA();
   else
      g_calculator = new CLaguerreAdaptiveScoreCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID)
     {
      Print("Critical Error: Failed to allocate Adaptive Score Calculator memory.");
      return(INIT_FAILED);
     }

   if(!g_calculator.Init(InpAdaptiveMethod, InpAdaptivePeriod, InpGammaMin, InpGammaMax, InpPeriod, is_ha))
     {
      Print("Critical Error: Failed to initialize Adaptive Score Calculator.");
      return(INIT_FAILED);
     }

//--- 5. Initialize Physical Signal MA Calculator
   if(InpShowSignal)
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
      g_signal_calculator = new CMovingAverageCalculator();
      if(CheckPointer(g_signal_calculator) == POINTER_INVALID || !g_signal_calculator.Init(InpSignalPeriod, InpSignalType))
        {
         Print("Critical Error: Failed to initialize Signal Line Calculator.");
         return(INIT_FAILED);
        }
     }
   else
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
     }

//--- 6. Dynamic Setup of Indicator Shortname
   string method_str = "";
   switch(InpAdaptiveMethod)
     {
      case METHOD_EFFICIENCY_RATIO:
         method_str = "ER";
         break;
      case METHOD_ATR:
         method_str = "ATR";
         break;
      case METHOD_STAND_DEV:
         method_str = "StDev";
         break;
     }

   string sig_str = "";
   if(InpShowSignal)
     {
      string sig_name = EnumToString(InpSignalType);
      StringToUpper(sig_name);
      sig_str = StringFormat(" | %s(%d)", sig_name, InpSignalPeriod);
     }

   string tf_str = g_is_mtf_mode ? (" " + EnumToString(g_calc_timeframe)) : "";
   string short_name = StringFormat("Laguerre Adaptive Score%s%s(%s, %d, %d)%s",
                                    is_ha ? " HA" : "",
                                    tf_str,
                                    method_str,
                                    InpAdaptivePeriod,
                                    InpPeriod,
                                    sig_str);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "Adaptive Score");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

//--- Drawing offset configuration
   int draw_begin = MathMax(InpAdaptivePeriod * 2, InpPeriod) + InpSignalPeriod + 5;
   if(g_is_mtf_mode)
      draw_begin = 0; // Handled dynamically in mapped buffers

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);

//--- 7. Initialize Background Synchronization Timer Daemon (Only if MTF is active)
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
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
//| Custom Indicator Calculation Loop                                |
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
   int required_bars = MathMax(InpAdaptivePeriod * 2, InpPeriod) + InpSignalPeriod + 10;
   if(rates_total < required_bars)
      return 0;

   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

//--- Force chronological indexing on current timeframe arrays
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

//===================================================================
// MODE 1: Current Timeframe calculation (Standard ultra-high speed)
//===================================================================
   if(!g_is_mtf_mode)
     {
      long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(ArraySize(g_double_volume) != rates_total)
        {
         ArrayResize(g_double_volume, rates_total);
         ArraySetAsSeries(g_double_volume, false);
        }

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

      // 1. Calculate Adaptive Score
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferScore);

      // 2. Calculate Signal MA
      if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
        {
         if(InpSignalType == VWMA)
            g_signal_calculator.CalculateOnArray(rates_total, prev_calculated, BufferScore, g_double_volume, BufferSignal, InpPeriod - 1);
         else
            g_signal_calculator.CalculateOnArray(rates_total, prev_calculated, BufferScore, BufferSignal, InpPeriod - 1);
        }
      else
        {
         for(int i = start_sync; i < rates_total; i++)
            BufferSignal[i] = EMPTY_VALUE;
        }

      // 3. Dynamic Histogram Color Classification
      for(int i = start_sync; i < rates_total; i++)
        {
         double score_val = BufferScore[i];
         if(score_val > InpLevelClimaxHigh)
            BufferColors[i] = 2.0; // Bull Climax (DeepSkyBlue)
         else
            if(score_val > InpLevelFlowHigh)
               BufferColors[i] = 1.0; // Bull Flow (LightSkyBlue)
            else
               if(score_val < InpLevelClimaxLow)
                  BufferColors[i] = 4.0; // Bear Climax (OrangeRed)
               else
                  if(score_val < InpLevelFlowLow)
                     BufferColors[i] = 3.0; // Bear Flow (Coral)
                  else
                     BufferColors[i] = 0.0; // Neutral (Gray)
        }

      return(rates_total);
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (Warp-free step synchronization)
//===================================================================
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars))
     {
      g_data_synced = false;
      return 0; // Wait for next tick to let history synchronize
     }

   g_data_synced = true;

//--- Check if a new HTF candle has opened
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

      g_htf_count = MathMin(htf_bars, 3000); // Guard rails to prevent memory overload

      // Resize all HTF caching arrays
      ArrayResize(h_time,       g_htf_count);
      ArrayResize(h_open,       g_htf_count);
      ArrayResize(h_high,       g_htf_count);
      ArrayResize(h_low,        g_htf_count);
      ArrayResize(h_close,      g_htf_count);
      ArrayResize(h_volume,     g_htf_count);
      ArrayResize(h_res_score,  g_htf_count);
      ArrayResize(h_res_color,  g_htf_count);
      ArrayResize(h_res_signal, g_htf_count);

      // Force chronological structure on high-level arrays
      ArraySetAsSeries(h_time,       false);
      ArraySetAsSeries(h_open,       false);
      ArraySetAsSeries(h_high,       false);
      ArraySetAsSeries(h_low,        false);
      ArraySetAsSeries(h_close,      false);
      ArraySetAsSeries(h_volume,     false);
      ArraySetAsSeries(h_res_score,  false);
      ArraySetAsSeries(h_res_color,  false);
      ArraySetAsSeries(h_res_signal, false);

      // Copy basic pricing data
      if(CopyTime(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   g_calc_timeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, g_calc_timeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      // Copy and extract proper volume types
      long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(vol_limit > 0)
        {
         long temp_vol[];
         if(CopyRealVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, temp_vol) == g_htf_count)
           {
            for(int i = 0; i < g_htf_count; i++)
               h_volume[i] = (double)temp_vol[i];
           }
        }
      else
        {
         long temp_vol[];
         if(CopyTickVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, temp_vol) == g_htf_count)
           {
            for(int i = 0; i < g_htf_count; i++)
               h_volume[i] = (double)temp_vol[i];
           }
        }

      //--- Calculate HTF core Adaptive Score
      g_calculator.Calculate(g_htf_count, 0, price_type, h_open, h_high, h_low, h_close, h_res_score);

      //--- Calculate HTF Signal MA
      if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
        {
         if(InpSignalType == VWMA)
            g_signal_calculator.CalculateOnArray(g_htf_count, 0, h_res_score, h_volume, h_res_signal, InpPeriod - 1);
         else
            g_signal_calculator.CalculateOnArray(g_htf_count, 0, h_res_score, h_res_signal, InpPeriod - 1);
        }

      //--- Calculate HTF dynamic coloring
      for(int i = 0; i < g_htf_count; i++)
        {
         double score_val = h_res_score[i];
         if(score_val > InpLevelClimaxHigh)
            h_res_color[i] = 2.0;
         else
            if(score_val > InpLevelFlowHigh)
               h_res_color[i] = 1.0;
            else
               if(score_val < InpLevelClimaxLow)
                  h_res_color[i] = 4.0;
               else
                  if(score_val < InpLevelFlowLow)
                     h_res_color[i] = 3.0;
                  else
                     h_res_color[i] = 0.0;
        }

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 5. Real-Time Update for the active forming HTF candle (Index: g_htf_count - 1) on every tick
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      double o[1], h[1], l[1], c[1];
      long v[1];
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

         long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
         if(vol_limit > 0)
           {
            if(CopyRealVolume(_Symbol, g_calc_timeframe, shift, 1, v) == 1)
               h_volume[live_idx] = (double)v[0];
           }
         else
           {
            if(CopyTickVolume(_Symbol, g_calc_timeframe, shift, 1, v) == 1)
               h_volume[live_idx] = (double)v[0];
           }

         // Stateful, O(1) mock update for the live HTF bar
         g_calculator.Calculate(g_htf_count, g_htf_count, price_type, h_open, h_high, h_low, h_close, h_res_score);

         if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
           {
            if(InpSignalType == VWMA)
               g_signal_calculator.CalculateOnArray(g_htf_count, g_htf_count, h_res_score, h_volume, h_res_signal, InpPeriod - 1);
            else
               g_signal_calculator.CalculateOnArray(g_htf_count, g_htf_count, h_res_score, h_res_signal, InpPeriod - 1);
           }

         double score_val = h_res_score[live_idx];
         if(score_val > InpLevelClimaxHigh)
            h_res_color[live_idx] = 2.0;
         else
            if(score_val > InpLevelFlowHigh)
               h_res_color[live_idx] = 1.0;
            else
               if(score_val < InpLevelClimaxLow)
                  h_res_color[live_idx] = 4.0;
               else
                  if(score_val < InpLevelFlowLow)
                     h_res_color[live_idx] = 3.0;
                  else
                     h_res_color[live_idx] = 0.0;
        }
     }

//--- 6. Warp-free step force (Staircase Solution anchor determination)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   int first_bar_of_forming_htf = rates_total - 1;
   while(first_bar_of_forming_htf > 0 &&
         iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
     {
      first_bar_of_forming_htf--;
     }
   first_bar_of_forming_htf++; // Anchor set to start of current HTF period block

   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

//--- 7. Map HTF Calculated results cleanly to the lower chart timeframe (O(1) complexity)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufferScore[i]  = h_res_score[idx_htf];
            BufferColors[i] = h_res_color[idx_htf];
            BufferSignal[i] = InpShowSignal ? h_res_signal[idx_htf] : EMPTY_VALUE;
           }
         else
           {
            BufferScore[i]  = EMPTY_VALUE;
            BufferColors[i] = 0.0;
            BufferSignal[i] = EMPTY_VALUE;
           }
        }
      else
        {
         BufferScore[i]  = EMPTY_VALUE;
         BufferColors[i] = 0.0;
         BufferSignal[i] = EMPTY_VALUE;
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler                                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
//--- Delegate asynchronous history checking and forced redraws to DataSync daemon
   int required_bars = MathMax(InpAdaptivePeriod * 2, InpPeriod) + InpSignalPeriod + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
