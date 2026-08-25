//+------------------------------------------------------------------+
//|                                           KScore_Anchored_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // First unified Native & MTF Anchored K-Score release
#property description "Statistical Session-Anchored K-Score Oscillator (AK-Score in Sigma units)."
#property description "Measures intra-session standardized dispersion from Session-Anchored KAMA."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

//--- Plot 1: AK-Score Histogram (Swapped Thermal Palette)
#property indicator_label1  "AK-Score"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Palette Configuration:
// 0: Noise/Neutral     (Gray)
// 1: Bullish Flow      (LightSkyBlue)
// 2: Bullish Climax    (DeepSkyBlue)
// 3: Bearish Flow      (Coral)
// 4: Bearish Climax    (OrangeRed)
#property indicator_color1  clrGray, clrLightSkyBlue, clrDeepSkyBlue, clrCoral, clrOrangeRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Optional Signal Line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrFireBrick
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Included Engines & Central Tools
#include <MyIncludes\KScore_Anchored_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe       = PERIOD_CURRENT;      // Calculation Timeframe (Current or HTF)

input group "--- Anchor Settings ---"
input ENUM_ANCHOR_PERIOD        InpResetPeriod     = ANCHOR_PERIOD_SESSION; // Anchor Reset Period
input int                       InpTzShift         = 0;                     // Timezone Shift (Hours)
input string                    InpCustomStart     = "08:00";               // Custom Session Start (HH:MM)
input string                    InpCustomEnd       = "17:00";               // Custom Session End (HH:MM)

input group "--- KAMA Core Settings ---"
input int                       InpErPeriod        = 10;                    // Efficiency Ratio Period
input int                       InpFastEmaPeriod   = 2;                     // Fastest EMA Period
input int                       InpSlowEmaPeriod   = 30;                    // Slowest EMA Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice     = PRICE_CLOSE_STD;       // Price Source (Standard / HA)

input group "--- Signal Line Settings ---"
input bool                      InpShowSignal      = true;                  // Show Signal Line?
input int                       InpSignalPeriod    = 5;                     // Signal Line Period
input ENUM_MA_TYPE              InpSignalType      = EMA;                   // Signal Line MA Type
input color                     InpColorSignal     = clrFireBrick;          // Signal Line Color

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Indicator Levels (Sigma Units) ---"
input double                    InpLevelFlowHigh   = 1.5;                   // High Warning Level (Bullish Flow)
input double                    InpLevelFlowLow    = -1.5;                  // Low Warning Level (Bearish Flow)
input double                    InpLevelClimaxHigh = 2.0;                   // High Climax Level (Bullish Climax)
input double                    InpLevelClimaxLow  = -2.0;                  // Low Climax Level (Bearish Climax)
input double                    InpLevelExtremeHigh= 2.5;                   // High Exhaustion Level
input double                    InpLevelExtremeLow = -2.5;                  // Low Exhaustion Level
input color                     InpLevelColor      = clrSilver;             // Levels Color
input ENUM_LINE_STYLE           InpLevelStyle      = STYLE_DOT;             // Levels Style

//--- Visual Indicator Buffers ---
double    BufferAKScore[];
double    BufferColors[];
double    BufferSignal[];

//--- Volume Cache (For Current Timeframe VWMA)
double    g_double_volume[];

//--- Internal HTF Data Caches
double    h_open[], h_high[], h_low[], h_close[], h_volume[];
double    h_res_akscore[], h_res_color[], h_res_signal[];
datetime  h_time[];

//--- Global Objects & State Management
CKScoreAnchoredCalculator *g_calculator = NULL;
CMovingAverageCalculator  *g_signal_calculator = NULL;

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

// 1. Resolve Timeframe and validate direction
   g_calc_timeframe = InpTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      PrintFormat("Critical Error: Target timeframe (%s) must be >= current timeframe (%s).",
                  EnumToString(g_calc_timeframe), EnumToString(Period()));
      return INIT_PARAMETERS_INCORRECT;
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

// 2. Bind buffers to index mapping
   SetIndexBuffer(0, BufferAKScore, INDICATOR_DATA);
   SetIndexBuffer(1, BufferColors,  INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferSignal,  INDICATOR_DATA);

   ArraySetAsSeries(BufferAKScore, false);
   ArraySetAsSeries(BufferColors,  false);
   ArraySetAsSeries(BufferSignal,  false);

   ArrayInitialize(BufferAKScore, 0.0);
   ArrayInitialize(BufferColors,  0.0);
   ArrayInitialize(BufferSignal,  EMPTY_VALUE);

   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Configure Dynamic Horizontal Sigma Levels
   IndicatorSetInteger(INDICATOR_LEVELS, 6);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpLevelFlowHigh);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpLevelFlowLow);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, InpLevelClimaxHigh);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, InpLevelClimaxLow);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 4, InpLevelExtremeHigh);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 5, InpLevelExtremeLow);

   IndicatorSetInteger(INDICATOR_LEVELCOLOR, InpLevelColor);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, InpLevelStyle);

// 4. Initialize Core Anchored K-Score Calculator
   g_calculator = new CKScoreAnchoredCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpResetPeriod, InpTzShift, InpCustomStart, InpCustomEnd,
                         InpErPeriod, InpFastEmaPeriod, InpSlowEmaPeriod, InpSourcePrice))
     {
      Print("Critical Error: Failed to initialize Anchored KScore Calculator Engine.");
      return INIT_FAILED;
     }

// 5. Initialize Optional Signal Line Calculator
   if(InpShowSignal)
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorSignal);
      PlotIndexSetString(1,  PLOT_LABEL, "Signal");

      g_signal_calculator = new CMovingAverageCalculator();
      if(CheckPointer(g_signal_calculator) == POINTER_INVALID ||
         !g_signal_calculator.Init(InpSignalPeriod, InpSignalType))
        {
         Print("Critical Error: Failed to initialize Signal Line Calculator.");
         return INIT_FAILED;
        }
     }
   else
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetString(1,  PLOT_LABEL, NULL);
     }

// 6. Dynamic Indicator Shortname Setup
   string ha_tag = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string sig_str = "";
   if(InpShowSignal)
     {
      string sig_name = EnumToString(InpSignalType);
      StringToUpper(sig_name);
      sig_str = StringFormat(" | %s(%d)", sig_name, InpSignalPeriod);
     }

   string short_name = StringFormat("AK-Score%s%s(%s, ER%d)%s",
                                    ha_tag, tf_str,
                                    EnumToString(InpResetPeriod), InpErPeriod,
                                    sig_str);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "AK-Score");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

// 7. Initialize Background Synchronization Timer (Only for MTF mode)
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_is_mtf_mode)
      EventKillTimer();

   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      delete g_calculator;
      g_calculator = NULL;
     }
   if(CheckPointer(g_signal_calculator) != POINTER_INVALID)
     {
      delete g_signal_calculator;
      g_signal_calculator = NULL;
     }
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
   int required_bars = InpErPeriod + 10;
   if(rates_total < required_bars || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Force chronological indexing on current timeframe arrays
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      // Convert volume for VWMA support
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

      // 1. Calculate Anchored K-Score
      g_calculator.Calculate(rates_total, prev_calculated, time, open, high, low, close, BufferAKScore);

      // 2. Calculate Signal Line
      if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
        {
         g_signal_calculator.CalculateOnArray(rates_total, prev_calculated, BufferAKScore, g_double_volume, BufferSignal, InpErPeriod);
        }
      else
        {
         for(int i = start_sync; i < rates_total; i++)
            BufferSignal[i] = EMPTY_VALUE;
        }

      // 3. Dynamic Swapped Thermal Palette Coloring
      for(int i = start_sync; i < rates_total; i++)
        {
         double k = BufferAKScore[i];

         if(k > InpLevelClimaxHigh)
            BufferColors[i] = 2.0; // DeepSkyBlue (Bullish Climax)
         else
            if(k > InpLevelFlowHigh)
               BufferColors[i] = 1.0; // LightSkyBlue (Bullish Flow)
            else
               if(k < InpLevelClimaxLow)
                  BufferColors[i] = 4.0; // OrangeRed (Bearish Climax)
               else
                  if(k < InpLevelFlowLow)
                     BufferColors[i] = 3.0; // Coral (Bearish Flow)
                  else
                     BufferColors[i] = 0.0; // Gray (Neutral Noise Zone)
        }

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (Warp-free Step Synchronization)
//===================================================================
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars))
     {
      g_data_synced = false;
      return 0;
     }

   g_data_synced = true;

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

      g_htf_count = MathMin(htf_bars, 3000); // Memory safeguard

      // Resize all HTF caching arrays
      ArrayResize(h_time,        g_htf_count);
      ArrayResize(h_open,        g_htf_count);
      ArrayResize(h_high,        g_htf_count);
      ArrayResize(h_low,         g_htf_count);
      ArrayResize(h_close,       g_htf_count);
      ArrayResize(h_volume,      g_htf_count);
      ArrayResize(h_res_akscore, g_htf_count);
      ArrayResize(h_res_color,   g_htf_count);
      ArrayResize(h_res_signal,  g_htf_count);

      // Force chronological alignment
      ArraySetAsSeries(h_time,        false);
      ArraySetAsSeries(h_open,        false);
      ArraySetAsSeries(h_high,        false);
      ArraySetAsSeries(h_low,         false);
      ArraySetAsSeries(h_close,       false);
      ArraySetAsSeries(h_volume,      false);
      ArraySetAsSeries(h_res_akscore, false);
      ArraySetAsSeries(h_res_color,   false);
      ArraySetAsSeries(h_res_signal,  false);

      // Copy pricing data
      if(CopyTime(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   g_calc_timeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, g_calc_timeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      // Copy volume data
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

      // Compute HTF Anchored K-Score Values
      g_calculator.Calculate(g_htf_count, 0, h_time, h_open, h_high, h_low, h_close, h_res_akscore);

      if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
         g_signal_calculator.CalculateOnArray(g_htf_count, 0, h_res_akscore, h_volume, h_res_signal, InpErPeriod);

      // Color HTF Cache
      for(int i = 0; i < g_htf_count; i++)
        {
         double k = h_res_akscore[i];
         if(k > InpLevelClimaxHigh)
            h_res_color[i] = 2.0;
         else
            if(k > InpLevelFlowHigh)
               h_res_color[i] = 1.0;
            else
               if(k < InpLevelClimaxLow)
                  h_res_color[i] = 4.0;
               else
                  if(k < InpLevelFlowLow)
                     h_res_color[i] = 3.0;
                  else
                     h_res_color[i] = 0.0;
        }

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

// 5. Stateful live-bar update for the active forming HTF candle
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      double o[1], h[1], l[1], c[1];
      datetime t_bar[1];
      long v[1];
      int shift = iBarShift(_Symbol, g_calc_timeframe, htf_time_current, false);
      if(shift >= 0 &&
         CopyTime(_Symbol,  g_calc_timeframe, shift, 1, t_bar) == 1 &&
         CopyOpen(_Symbol,  g_calc_timeframe, shift, 1, o) == 1 &&
         CopyHigh(_Symbol,  g_calc_timeframe, shift, 1, h) == 1 &&
         CopyLow(_Symbol,   g_calc_timeframe, shift, 1, l) == 1 &&
         CopyClose(_Symbol, g_calc_timeframe, shift, 1, c) == 1)
        {
         h_time[live_idx]  = t_bar[0];
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

         // Mock update on live bar
         g_calculator.Calculate(g_htf_count, g_htf_count, h_time, h_open, h_high, h_low, h_close, h_res_akscore);

         if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
            g_signal_calculator.CalculateOnArray(g_htf_count, g_htf_count, h_res_akscore, h_volume, h_res_signal, InpErPeriod);

         double k = h_res_akscore[live_idx];
         if(k > InpLevelClimaxHigh)
            h_res_color[live_idx] = 2.0;
         else
            if(k > InpLevelFlowHigh)
               h_res_color[live_idx] = 1.0;
            else
               if(k < InpLevelClimaxLow)
                  h_res_color[live_idx] = 4.0;
               else
                  if(k < InpLevelFlowLow)
                     h_res_color[live_idx] = 3.0;
                  else
                     h_res_color[live_idx] = 0.0;
        }
     }

// 6. Forming LTF Block Flat-Force Anchor (The Staircase Solution)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   int first_bar_of_forming_htf = rates_total - 1;
   while(first_bar_of_forming_htf > 0 &&
         iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
     {
      first_bar_of_forming_htf--;
     }
   first_bar_of_forming_htf++;

   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

// 7. Chronological Mapping Loop to Chart Timeframe
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufferAKScore[i] = h_res_akscore[idx_htf];
            BufferColors[i]  = h_res_color[idx_htf];
            BufferSignal[i]  = InpShowSignal ? h_res_signal[idx_htf] : EMPTY_VALUE;
           }
         else
           {
            BufferAKScore[i] = 0.0;
            BufferColors[i]  = 0.0;
            BufferSignal[i]  = EMPTY_VALUE;
           }
        }
      else
        {
         BufferAKScore[i] = 0.0;
         BufferColors[i]  = 0.0;
         BufferSignal[i]  = EMPTY_VALUE;
        }
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = InpErPeriod + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
