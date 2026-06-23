//+------------------------------------------------------------------+
//|                                                 Velocity_Pro.mq5 |
//|                    Velocity vs Scaler Speed Envelope             |
//|                    Copyright 2026, xxxxxxxx                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.40" // Swapped color polarity: Bullish (Blue tones) and Bearish (Red/Coral tones)
#property description "Displays Velocity (Histogram), Speed Envelope, and customizable Signal Line."
#property description "Touching the envelope lines signals climatic efficiency."

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

//--- Plot 2: Speed Positive (Top)
#property indicator_label2  "Speed (+)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDarkOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: Speed Negative (Bottom)
#property indicator_label3  "Speed (-)"
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
input int               InpVelPeriod     = 3;              // Velocity Vector Lookback
input int               InpATRPeriod     = 14;             // Volatility Base (ATR)
input double            InpThresholdLow  = 0.3;            // Low Threshold (Flow Zone)
input double            InpThresholdHigh = 1.0;            // High Threshold (Climax Zone)
input bool              InpShowSpeed     = true;           // Show Speed Envelope?

//--- Signal Line Parameters (Dynamic MA Engine Integration)
input bool              InpShowSignal    = true;            // Show Signal Line?
input int               InpSignalPeriod  = 5;               // Signal Line Period
input ENUM_MA_TYPE      InpSignalType    = SMA;             // Signal Line MA Type

//--- Buffers
double BufVel[];
double BufCol[];
double BufSpeedPos[];
double BufSpeedNeg[];
double BufSignal[];

//--- Volume Cache to support Volume-Weighted types (VWMA) on custom arrays
double g_double_volume[];

//--- Global Engines
CATRCalculator           *g_atr;
CMovingAverageCalculator *g_signal_calculator;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
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
   string name = "";
   if(InpShowSignal)
     {
      string sig_name = EnumToString(InpSignalType);
      StringToUpper(sig_name);
      name = StringFormat("Velocity(%d) %s(%d)", InpVelPeriod, sig_name, InpSignalPeriod);
     }
   else
     {
      name = StringFormat("Velocity(%d)", InpVelPeriod);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, name);
   PlotIndexSetString(0, PLOT_LABEL, "Velocity");
   PlotIndexSetString(1, PLOT_LABEL, "Speed (+)");
   PlotIndexSetString(2, PLOT_LABEL, "Speed (-)");
   IndicatorSetInteger(INDICATOR_DIGITS, 3);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
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
   if(rates_total < InpATRPeriod + InpVelPeriod + 5)
      return 0;

//--- Convert long volume to double cache array in O(1) incrementally
   ArrayResize(g_double_volume, rates_total);
   int start_sync = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

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

//--- 1. Calculate underlying Average True Range
   double atr_buf[];
   g_atr.Calculate(rates_total, prev_calculated, open, high, low, close, atr_buf);

//--- 2. Calculate Velocity & Speed Envelopes (O(1) incremental)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpATRPeriod + InpVelPeriod;

   for(int i = start; i < rates_total; i++)
     {
      double atr = atr_buf[i];
      if(atr == 0)
        {
         BufVel[i] = 0.0;
         BufSpeedPos[i] = 0.0;
         BufSpeedNeg[i] = 0.0;
         continue;
        }

      // Calculate Velocity Vector (Directional Slope)
      double vel = CMetricsTools::CalculateSlope(close[i], close[i - InpVelPeriod], atr, InpVelPeriod);
      BufVel[i] = vel;

      // Color coding logic based on swapped bull/bear thermal thresholds
      // 0: Gray (Neutral / No edge)
      // 1: LightSkyBlue (Bullish Flow / Trend building)
      // 2: DeepSkyBlue (Bullish Climax / Exhaustion zone)
      // 3: Coral (Bearish Flow / Trend building)
      // 4: OrangeRed (Bearish Climax / Exhaustion zone)
      if(vel >= InpThresholdHigh)
         BufCol[i] = 2.0; // Index 2: DeepSkyBlue
      else
         if(vel >= InpThresholdLow)
            BufCol[i] = 1.0; // Index 1: LightSkyBlue
         else
            if(vel <= -InpThresholdHigh)
               BufCol[i] = 4.0; // Index 4: OrangeRed
            else
               if(vel <= -InpThresholdLow)
                  BufCol[i] = 3.0; // Index 3: Coral
               else
                  BufCol[i] = 0.0; // Index 0: Gray

      // Calculate Speed Scalar (Total Path Length over Period / normalizer)
      double path_length = 0.0;
      for(int k = 0; k < InpVelPeriod; k++)
        {
         path_length += MathAbs(close[i - k] - close[i - k - 1]);
        }
      double speed = (path_length / InpVelPeriod) / atr;

      // Mirroring envelopes for both upside and downside analysis
      BufSpeedPos[i] = speed;
      BufSpeedNeg[i] = -speed;
     }

//--- 3. Calculate Optional Signal Line on top of Velocity values (Handles VWMA dynamically)
   if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
     {
      // Source start index is 'InpATRPeriod + InpVelPeriod' since Velocity before that is invalid
      g_signal_calculator.CalculateOnArray(rates_total, prev_calculated, BufVel, g_double_volume, BufSignal, InpATRPeriod + InpVelPeriod);
     }

   return rates_total;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
