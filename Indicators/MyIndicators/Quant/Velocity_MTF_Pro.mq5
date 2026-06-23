//+------------------------------------------------------------------+
//|                                             Velocity_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.50" // Upgraded with 5-Zone Swapped Thermal Kinetics, Flat-Force step-alignment, and VWMA Signal Line
#property description "Kinematics Velocity & Speed Envelopes (Multi-Timeframe)."
#property description "Displays Higher Timeframe Velocity, Speed, and Signal cleanly without live-bar warping."

#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   4

//--- Institutional Levels Configuration (4-level Kinematic boundaries)
#property indicator_level1 1.0
#property indicator_level2 -1.0
#property indicator_level3 0.3
#property indicator_level4 -0.3
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: Velocity Histogram (Swapped Bull/Bear Thermal Palette)
#property indicator_label1  "Velocity MTF"
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

//--- Plot 2: Speed Positive (Top)
#property indicator_label2  "Speed (+) MTF"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDarkOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: Speed Negative (Bottom)
#property indicator_label3  "Speed (-) MTF"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDarkOrange
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Plot 4: Optional Signal Line (Wyckoff Reversal Trigger)
#property indicator_label4  "Signal"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrFireBrick
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\Metrics_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Parameters ---
input ENUM_TIMEFRAMES   InpTimeframe     = PERIOD_M5;       // Target Higher Timeframe
input int               InpVelPeriod     = 3;               // Velocity Vector Lookback
input int               InpATRPeriod     = 14;              // Volatility Base (ATR)
input double            InpThresholdLow  = 0.3;             // Low Threshold (Flow Zone)
input double            InpThresholdHigh = 1.0;             // High Threshold (Climax Zone)
input bool              InpShowSpeed     = true;            // Show Speed Envelope?

//--- Signal Line Parameters (Dynamic MA Engine Integration)
input bool              InpShowSignal    = true;            // Show Signal Line?
input int               InpSignalPeriod  = 5;               // Signal Line Period
input ENUM_MA_TYPE      InpSignalType    = SMA;             // Signal Line MA Type

//--- Buffers (Visual)
double BufVel[];
double BufCol[];
double BufSpeedPos[];
double BufSpeedNeg[];
double BufSignal[];

//--- Internal HTF Data Caches
double h_vel[], h_spd[], h_sig[]; // HTF Results cached
datetime h_time[];
double h_open[], h_high[], h_low[], h_close[];
long   h_vol[]; // HTF raw volume cache
double h_vol_double[]; // HTF volume cast to double to support VWMA Signal line

//--- Global HTF State Tracking
CATRCalculator           *g_atr;
CMovingAverageCalculator *g_signal_calculator;
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

//--- Bind Buffers
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

//--- Configure Speed Envelope Displays
   if(!InpShowSpeed)
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
     }
   else
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_LINE);
     }

//--- Configure Optional Signal Line Calculator
   if(InpShowSignal)
     {
      // Explicitly restore DRAW_LINE & Label in case it was previously disabled
      PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetString(3, PLOT_LABEL, "Signal");

      g_signal_calculator = new CMovingAverageCalculator();
      if(CheckPointer(g_signal_calculator) == POINTER_INVALID || !g_signal_calculator.Init(InpSignalPeriod, InpSignalType))
        {
         Print("Error: Failed to initialize Signal Line Calculator Engine.");
         return INIT_FAILED;
        }
     }
   else
     {
      // Set DRAW_NONE and clear Label to fully purge it from the MT5 Data Window
      PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetString(3, PLOT_LABEL, NULL);
     }

//--- Configure Core Volatility Engine
   g_atr = new CATRCalculator();
   if(CheckPointer(g_atr) == POINTER_INVALID || !g_atr.Init(InpATRPeriod, ATR_POINTS))
     {
      Print("Error: Failed to initialize ATR Calculator Engine.");
      return INIT_FAILED;
     }

//--- Dynamically set the indicator short name
   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string name = "";
   if(InpShowSignal)
     {
      string sig_name = EnumToString(InpSignalType);
      StringToUpper(sig_name);
      name = StringFormat("Velocity MTF %s(%d) %s(%d)", tf_name, InpVelPeriod, sig_name, InpSignalPeriod);
     }
   else
     {
      name = StringFormat("Velocity MTF %s(%d)", tf_name, InpVelPeriod);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, name);
   PlotIndexSetString(0, PLOT_LABEL, "Velocity MTF");
   PlotIndexSetString(1, PLOT_LABEL, "Speed (+) MTF");
   PlotIndexSetString(2, PLOT_LABEL, "Speed (-) MTF");
   IndicatorSetInteger(INDICATOR_DIGITS, 3);

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
   if(CheckPointer(g_atr) != POINTER_INVALID)
      delete g_atr;
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
//--- Ensure target timeframe history is ready
   int required_bars = InpATRPeriod + InpVelPeriod + 10;
   if(!EnsureHTFDataReady(_Symbol, InpTimeframe, required_bars))
     {
      g_data_synced = false;
      return 0; // Wait for next tick to let history load
     }

   g_data_synced = true;

//--- Determine best volume array (Use Real Volume if available, otherwise fallback to Tick Volume)
   long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

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

      ArrayResize(h_time,       g_htf_count);
      ArrayResize(h_open,       g_htf_count);
      ArrayResize(h_high,       g_htf_count);
      ArrayResize(h_low,        g_htf_count);
      ArrayResize(h_close,      g_htf_count);
      ArrayResize(h_vol,        g_htf_count);
      ArrayResize(h_vol_double, g_htf_count);

      ArrayResize(h_vel,        g_htf_count);
      ArrayResize(h_spd,        g_htf_count);
      ArrayResize(h_sig,        g_htf_count);

      if(CopyTime(_Symbol,  InpTimeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  InpTimeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  InpTimeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   InpTimeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, InpTimeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      // High-Performance dynamic volume routing on the HTF Timeline
      int copied_vol = 0;
      if(volume_limit > 0)
         copied_vol = CopyRealVolume(_Symbol, InpTimeframe, 0, g_htf_count, h_vol);
      else
         copied_vol = CopyTickVolume(_Symbol, InpTimeframe, 0, g_htf_count, h_vol);

      if(copied_vol != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      // Convert HTF volume cache to double precision
      for(int j = 0; j < g_htf_count; j++)
         h_vol_double[j] = (double)h_vol[j];

      // A. Calculate ATR on HTF (Closed bars and forming bar initialized)
      double h_atr_buf[];
      g_atr.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_atr_buf);

      // B. Calculate HTF Velocity and Speed (Closed bars only!)
      // Notice the limit is 'g_htf_count - 1' (excluding the live forming bar)
      for(int j = InpATRPeriod + InpVelPeriod; j < g_htf_count - 1; j++)
        {
         double atr = h_atr_buf[j];
         if(atr == 0)
           {
            h_vel[j] = 0.0;
            h_spd[j] = 0.0;
            continue;
           }

         // Velocity Vector (Directional Slope)
         h_vel[j] = CMetricsTools::CalculateSlope(h_close[j], h_close[j - InpVelPeriod], atr, InpVelPeriod);

         // Speed Scalar (Path Length)
         double path_length = 0.0;
         for(int k = 0; k < InpVelPeriod; k++)
           {
            path_length += MathAbs(h_close[j - k] - h_close[j - k - 1]);
           }
         h_spd[j] = (path_length / InpVelPeriod) / atr;
        }

      // C. Calculate Optional Signal Line on HTF
      if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
        {
         g_signal_calculator.CalculateOnArray(g_htf_count, 0, h_vel, h_vol_double, h_sig, InpATRPeriod + InpVelPeriod);
        }

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 2. Live Update for the Current Forming HTF Bar (Index: g_htf_count - 1) on every tick!
   int live_idx = g_htf_count - 1;
   if(live_idx >= InpATRPeriod + InpVelPeriod)
     {
      double o[1], h[1], l[1], c[1];
      long vol[1];
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

         // Copy live volume dynamically
         int copied = 0;
         if(volume_limit > 0)
            copied = CopyRealVolume(_Symbol, InpTimeframe, shift, 1, vol);
         else
            copied = CopyTickVolume(_Symbol, InpTimeframe, shift, 1, vol);

         if(copied == 1)
           {
            h_vol[live_idx] = vol[0];
            h_vol_double[live_idx] = (double)vol[0];
           }

         // Recalculate ATR, Velocity and Speed on the live HTF index in O(1)
         double h_atr_single_buf[];
         g_atr.Calculate(g_htf_count, live_idx, h_open, h_high, h_low, h_close, h_atr_single_buf);

         double atr = h_atr_single_buf[live_idx];
         if(atr > 0)
           {
            h_vel[live_idx] = CMetricsTools::CalculateSlope(h_close[live_idx], h_close[live_idx - InpVelPeriod], atr, InpVelPeriod);

            double path_length = 0.0;
            for(int k = 0; k < InpVelPeriod; k++)
              {
               path_length += MathAbs(h_close[live_idx - k] - h_close[live_idx - k - 1]);
              }
            h_spd[live_idx] = (path_length / InpVelPeriod) / atr;
           }
         else
           {
            h_vel[live_idx] = 0.0;
            h_spd[live_idx] = 0.0;
           }

         // Recalculate Signal Line on HTF live index
         if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
           {
            g_signal_calculator.CalculateOnArray(g_htf_count, live_idx, h_vel, h_vol_double, h_sig, InpATRPeriod + InpVelPeriod);
           }
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
            double val_v = h_vel[idx_htf];
            double val_s = h_spd[idx_htf];

            BufVel[i]      = val_v;
            BufSpeedPos[i] = val_s;
            BufSpeedNeg[i] = -val_s;

            if(InpShowSignal)
               BufSignal[i] = h_sig[idx_htf];
            else
               BufSignal[i] = EMPTY_VALUE;

            // Swapped 5-Zone Color Logic (Blue for Bullish, Red/Coral for Bearish)
            if(val_v >= InpThresholdHigh)
               BufCol[i] = 2.0; // Index 2: DeepSkyBlue (Bullish Climax)
            else
               if(val_v >= InpThresholdLow)
                  BufCol[i] = 1.0; // Index 1: LightSkyBlue (Bullish Flow)
               else
                  if(val_v <= -InpThresholdHigh)
                     BufCol[i] = 4.0; // Index 4: OrangeRed (Bearish Climax)
                  else
                     if(val_v <= -InpThresholdLow)
                        BufCol[i] = 3.0; // Index 3: Coral (Bearish Flow)
                     else
                        BufCol[i] = 0.0; // Index 0: Gray (Neutral Noise)
           }
         else
           {
            BufVel[i]      = EMPTY_VALUE;
            BufSpeedPos[i] = EMPTY_VALUE;
            BufSpeedNeg[i] = EMPTY_VALUE;
            BufSignal[i]   = EMPTY_VALUE;
            BufCol[i]      = 0.0;
           }
        }
      else
        {
         BufVel[i]      = EMPTY_VALUE;
         BufSpeedPos[i] = EMPTY_VALUE;
         BufSpeedNeg[i] = EMPTY_VALUE;
         BufSignal[i]   = EMPTY_VALUE;
         BufCol[i]      = 0.0;
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
      int required_bars = InpATRPeriod + InpVelPeriod + 5;
      if(EnsureHTFDataReady(_Symbol, InpTimeframe, required_bars))
        {
         g_data_synced = true;
         ChartRedraw(); // Force MT5 to invoke OnCalculate
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
