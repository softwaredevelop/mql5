//+------------------------------------------------------------------+
//|                                                 Velocity_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "4.00" // Unified Native & MTF Release with Modular Kinematics Engine
#property description "Kinematic Velocity Vector vs. Speed Envelope Indicator."
#property description "Displays Velocity (Histogram), Speed Envelopes, and customizable Signal Line with Native & MTF support."

#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   4

//--- Plot 1: Velocity Histogram (Swapped Bull/Bear Thermal Palette)
#property indicator_label1  "Velocity"
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

//--- Plot 2: Speed Positive (Top Envelope)
#property indicator_label2  "Speed (+)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDarkOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: Speed Negative (Bottom Envelope)
#property indicator_label3  "Speed (-)"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDarkOrange
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Plot 4: Optional Smoothed Signal Line
#property indicator_label4  "Signal"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrFireBrick
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//--- Included Engines & Central Tools
#include <MyIncludes\Velocity_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;      // Calculation Timeframe (Current or HTF)

input group "--- Velocity Kinematics Settings ---"
input int                       InpVelPeriod      = 3;                   // Velocity Vector Lookback
input int                       InpATRPeriod      = 14;                  // Volatility Base (ATR Period)
input double                    InpThresholdLow   = 0.3;                 // Low Threshold (Flow Zone)
input double                    InpThresholdHigh  = 1.0;                 // High Threshold (Climax Zone)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;     // Velocity Price Source (Standard / HA)
input ENUM_ATR_SOURCE           InpATRSource      = ATR_SOURCE_STANDARD; // ATR Volatility Source

input group "--- Speed Envelope Settings ---"
input bool                      InpShowSpeed      = true;                // Show Speed Envelope?
input color                     InpColorSpeed     = clrDarkOrange;       // Speed Envelope Color
input ENUM_LINE_STYLE           InpStyleSpeed     = STYLE_SOLID;         // Speed Envelope Style
input int                       InpWidthSpeed     = 1;                   // Speed Envelope Width

input group "--- Signal Line Settings ---"
input bool                      InpShowSignal     = true;                // Show Signal Line?
input int                       InpSignalPeriod   = 5;                   // Signal Line Period
input ENUM_MA_TYPE              InpSignalType     = EMA;                 // Signal Line MA Type
input color                     InpColorSignal    = clrFireBrick;        // Signal Line Color

input group "--- Indicator Levels ---"
input double                    InpLevelClimaxPos = 1.0;                 // Positive Climax Level
input double                    InpLevelFlowPos   = 0.3;                 // Positive Flow Level
input double                    InpLevelFlowNeg   =-0.3;                 // Negative Flow Level
input double                    InpLevelClimaxNeg =-1.0;                 // Negative Climax Level
input color                     InpLevelColor     = clrSilver;           // Level Lines Color
input ENUM_LINE_STYLE           InpLevelStyle     = STYLE_DOT;           // Level Lines Style

//--- Visual Indicator Buffers ---
double BufVel[];
double BufCol[];
double BufSpeedPos[];
double BufSpeedNeg[];
double BufSignal[];

//--- Volume Cache (For Current Timeframe VWMA)
double g_double_volume[];

//--- Internal HTF Data Caches (Chronological Arrays)
double h_open[], h_high[], h_low[], h_close[];
long   h_tick_vol[], h_vol[];
double h_res_vel[], h_res_col[];
double h_res_sp_pos[], h_res_sp_neg[], h_res_sig[];
datetime h_time[];

//--- Global Objects & State Management
CVelocityCalculator      *g_velocity_calc    = NULL;
CMovingAverageCalculator *g_signal_calculator = NULL;

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

// 2. Bind Buffers
   SetIndexBuffer(0, BufVel,      INDICATOR_DATA);
   SetIndexBuffer(1, BufCol,      INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufSpeedPos, INDICATOR_DATA);
   SetIndexBuffer(3, BufSpeedNeg, INDICATOR_DATA);
   SetIndexBuffer(4, BufSignal,   INDICATOR_DATA);

   ArraySetAsSeries(BufVel,      false);
   ArraySetAsSeries(BufCol,      false);
   ArraySetAsSeries(BufSpeedPos, false);
   ArraySetAsSeries(BufSpeedNeg, false);
   ArraySetAsSeries(BufSignal,   false);

   ArrayInitialize(BufVel,      0.0);
   ArrayInitialize(BufCol,      0.0);
   ArrayInitialize(BufSpeedPos, EMPTY_VALUE);
   ArrayInitialize(BufSpeedNeg, EMPTY_VALUE);
   ArrayInitialize(BufSignal,   EMPTY_VALUE);

// Prevent drawing to 0.0 for empty values
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Configure Speed Envelopes Visuals
   if(InpShowSpeed)
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorSpeed);
      PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleSpeed);
      PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthSpeed);
      PlotIndexSetString(1,  PLOT_LABEL, "Speed (+)");

      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColorSpeed);
      PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpStyleSpeed);
      PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpWidthSpeed);
      PlotIndexSetString(2,  PLOT_LABEL, "Speed (-)");
     }
   else
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetString(1,  PLOT_LABEL, NULL);
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetString(2,  PLOT_LABEL, NULL);
     }

// 4. Configure Optional Signal Line
   if(InpShowSignal)
     {
      PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpColorSignal);
      PlotIndexSetString(3,  PLOT_LABEL, "Signal");

      g_signal_calculator = new CMovingAverageCalculator();
      if(CheckPointer(g_signal_calculator) == POINTER_INVALID ||
         !g_signal_calculator.Init(InpSignalPeriod, InpSignalType))
        {
         Print("Critical Error: Failed to initialize Signal Line Calculator Engine.");
         return INIT_FAILED;
        }
     }
   else
     {
      PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetString(3,  PLOT_LABEL, NULL);
     }

// 5. Configure 4 Kinematic Levels
   IndicatorSetInteger(INDICATOR_LEVELS, 4);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpLevelClimaxPos);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpLevelFlowPos);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, InpLevelFlowNeg);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, InpLevelClimaxNeg);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, InpLevelColor);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, InpLevelStyle);

   int warmup = InpATRPeriod + InpVelPeriod;
   int draw_begin = warmup + InpSignalPeriod + 2;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 3);

// 6. Initialize Core Velocity Engine
   g_velocity_calc = new CVelocityCalculator();
   if(CheckPointer(g_velocity_calc) == POINTER_INVALID ||
      !g_velocity_calc.Init(InpVelPeriod, InpATRPeriod, InpSourcePrice, InpATRSource))
     {
      Print("Critical Error: Failed to initialize Velocity Calculator Engine.");
      return INIT_FAILED;
     }

   string ha_tag = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string sig_str = "";
   if(InpShowSignal)
     {
      string sig_name = EnumToString(InpSignalType);
      StringToUpper(sig_name);
      sig_str = StringFormat(" | %s(%d)", sig_name, InpSignalPeriod);
     }

   string short_name = StringFormat("Velocity%s%s(V%d, ATR%d)%s",
                                    ha_tag, tf_str,
                                    InpVelPeriod, InpATRPeriod,
                                    sig_str);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "Velocity");

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

   if(CheckPointer(g_velocity_calc) != POINTER_INVALID)
     {
      delete g_velocity_calc;
      g_velocity_calc = NULL;
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
   int warmup = InpATRPeriod + InpVelPeriod;
   int required_bars = warmup + InpSignalPeriod + 10;

   if(rates_total < required_bars || CheckPointer(g_velocity_calc) == POINTER_INVALID)
      return 0;

// Force chronological indexing
   ArraySetAsSeries(time,        false);
   ArraySetAsSeries(open,        false);
   ArraySetAsSeries(high,        false);
   ArraySetAsSeries(low,         false);
   ArraySetAsSeries(close,       false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume,      false);

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
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

      // 1. Compute Velocity & Speed Envelopes
      g_velocity_calc.Calculate(rates_total, prev_calculated, open, high, low, close,
                                BufVel, BufCol, BufSpeedPos, BufSpeedNeg,
                                InpThresholdLow, InpThresholdHigh);

      // 2. Compute Signal MA Line
      if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
        {
         g_signal_calculator.CalculateOnArray(rates_total, prev_calculated, BufVel, g_double_volume, BufSignal, warmup);
        }
      else
        {
         for(int i = start_sync; i < rates_total; i++)
            BufSignal[i] = EMPTY_VALUE;
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

      g_htf_count = MathMin(htf_bars, 3000);

      // Resize all HTF caching arrays
      ArrayResize(h_time,        g_htf_count);
      ArrayResize(h_open,        g_htf_count);
      ArrayResize(h_high,        g_htf_count);
      ArrayResize(h_low,         g_htf_count);
      ArrayResize(h_close,       g_htf_count);
      ArrayResize(h_tick_vol,    g_htf_count);
      ArrayResize(h_vol,         g_htf_count);
      ArrayResize(h_res_vel,     g_htf_count);
      ArrayResize(h_res_col,     g_htf_count);
      ArrayResize(h_res_sp_pos,  g_htf_count);
      ArrayResize(h_res_sp_neg,  g_htf_count);
      ArrayResize(h_res_sig,     g_htf_count);

      ArraySetAsSeries(h_time,        false);
      ArraySetAsSeries(h_open,        false);
      ArraySetAsSeries(h_high,        false);
      ArraySetAsSeries(h_low,         false);
      ArraySetAsSeries(h_close,       false);
      ArraySetAsSeries(h_tick_vol,    false);
      ArraySetAsSeries(h_vol,         false);
      ArraySetAsSeries(h_res_vel,     false);
      ArraySetAsSeries(h_res_col,     false);
      ArraySetAsSeries(h_res_sp_pos,  false);
      ArraySetAsSeries(h_res_sp_neg,  false);
      ArraySetAsSeries(h_res_sig,     false);

      if(CopyTime(_Symbol,       g_calc_timeframe, 0, g_htf_count, h_time)     != g_htf_count ||
         CopyOpen(_Symbol,       g_calc_timeframe, 0, g_htf_count, h_open)     != g_htf_count ||
         CopyHigh(_Symbol,       g_calc_timeframe, 0, g_htf_count, h_high)     != g_htf_count ||
         CopyLow(_Symbol,        g_calc_timeframe, 0, g_htf_count, h_low)      != g_htf_count ||
         CopyClose(_Symbol,      g_calc_timeframe, 0, g_htf_count, h_close)    != g_htf_count ||
         CopyTickVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, h_tick_vol) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(vol_limit > 0)
         CopyRealVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, h_vol);
      else
         ArrayCopy(h_vol, h_tick_vol, 0, 0, g_htf_count);

      // Compute HTF Velocity & Envelopes
      g_velocity_calc.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close,
                                h_res_vel, h_res_col, h_res_sp_pos, h_res_sp_neg,
                                InpThresholdLow, InpThresholdHigh);

      if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
        {
         double htf_double_vol[];
         ArrayResize(htf_double_vol, g_htf_count);
         ArraySetAsSeries(htf_double_vol, false);
         for(int k = 0; k < g_htf_count; k++)
            htf_double_vol[k] = (double)h_vol[k];

         g_signal_calculator.CalculateOnArray(g_htf_count, 0, h_res_vel, htf_double_vol, h_res_sig, warmup);
        }

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

// 5. Stateful live-bar update for active forming HTF candle
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      double o[1], h[1], l[1], c[1];
      datetime t_bar[1];
      long tv[1], v[1];

      int shift = iBarShift(_Symbol, g_calc_timeframe, htf_time_current, false);
      if(shift >= 0 &&
         CopyTime(_Symbol,       g_calc_timeframe, shift, 1, t_bar) == 1 &&
         CopyOpen(_Symbol,       g_calc_timeframe, shift, 1, o)     == 1 &&
         CopyHigh(_Symbol,       g_calc_timeframe, shift, 1, h)     == 1 &&
         CopyLow(_Symbol,        g_calc_timeframe, shift, 1, l)     == 1 &&
         CopyClose(_Symbol,      g_calc_timeframe, shift, 1, c)     == 1 &&
         CopyTickVolume(_Symbol, g_calc_timeframe, shift, 1, tv)    == 1)
        {
         h_time[live_idx]     = t_bar[0];
         h_open[live_idx]     = o[0];
         h_high[live_idx]     = h[0];
         h_low[live_idx]      = l[0];
         h_close[live_idx]    = c[0];
         h_tick_vol[live_idx] = tv[0];

         long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
         if(vol_limit > 0 && CopyRealVolume(_Symbol, g_calc_timeframe, shift, 1, v) == 1)
            h_vol[live_idx] = v[0];
         else
            h_vol[live_idx] = tv[0];

         // Mock update on live HTF bar
         g_velocity_calc.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close,
                                   h_res_vel, h_res_col, h_res_sp_pos, h_res_sp_neg,
                                   InpThresholdLow, InpThresholdHigh);

         if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
           {
            double htf_double_vol[];
            ArrayResize(htf_double_vol, g_htf_count);
            ArraySetAsSeries(htf_double_vol, false);
            for(int k = 0; k < g_htf_count; k++)
               htf_double_vol[k] = (double)h_vol[k];

            g_signal_calculator.CalculateOnArray(g_htf_count, g_htf_count, h_res_vel, htf_double_vol, h_res_sig, warmup);
           }
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

// 7. Chronological Mapping Loop to Chart Timeframe (5 Buffers)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufVel[i]      = h_res_vel[idx_htf];
            BufCol[i]      = h_res_col[idx_htf];
            BufSpeedPos[i] = InpShowSpeed ? h_res_sp_pos[idx_htf] : EMPTY_VALUE;
            BufSpeedNeg[i] = InpShowSpeed ? h_res_sp_neg[idx_htf] : EMPTY_VALUE;
            BufSignal[i]   = InpShowSignal ? h_res_sig[idx_htf] : EMPTY_VALUE;
           }
         else
           {
            BufVel[i]      = 0.0;
            BufCol[i]      = 0.0;
            BufSpeedPos[i] = EMPTY_VALUE;
            BufSpeedNeg[i] = EMPTY_VALUE;
            BufSignal[i]   = EMPTY_VALUE;
           }
        }
      else
        {
         BufVel[i]      = 0.0;
         BufCol[i]      = 0.0;
         BufSpeedPos[i] = EMPTY_VALUE;
         BufSpeedNeg[i] = EMPTY_VALUE;
         BufSignal[i]   = EMPTY_VALUE;
        }
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int warmup = InpATRPeriod + InpVelPeriod;
   int required_bars = warmup + InpSignalPeriod + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
