//+------------------------------------------------------------------+
//|                                                 Velocity_Pro.mq5 |
//|                    Velocity vs Scaler Speed Envelope             |
//|                    Copyright 2026, xxxxxxxx                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.10" // Added Mirrored Speed (Negative Scalar)
#property description "Displays Velocity (Histogram) and Speed Envelope."
#property description "Touching the envelope lines signals climatic efficiency."

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   3

//--- Levels
#property indicator_level1 1.0
#property indicator_level2 -1.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: Velocity Histogram
#property indicator_label1  "Velocity"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrLime, clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Speed Positive (Top)
#property indicator_label2  "Speed (+)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGold
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: Speed Negative (Bottom)
#property indicator_label3  "Speed (-)"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGold
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\Metrics_Tools.mqh>

//--- Parameters
input int               InpVelPeriod   = 3;
input int               InpATRPeriod   = 14;
input double            InpThreshold   = 1.0;
input bool              InpShowSpeed   = true;

//--- Buffers
double BufVel[];
double BufCol[];
double BufSpeedPos[];
double BufSpeedNeg[];

CATRCalculator *g_atr;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufVel, INDICATOR_DATA);
   SetIndexBuffer(1, BufCol, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufSpeedPos, INDICATOR_DATA);
   SetIndexBuffer(3, BufSpeedNeg, INDICATOR_DATA);

   if(!InpShowSpeed)
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
     }

   g_atr = new CATRCalculator();
   g_atr.Init(InpATRPeriod, ATR_POINTS);

   string name = StringFormat("Velocity(%d)", InpVelPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int r) { if(CheckPointer(g_atr)==POINTER_DYNAMIC) delete g_atr; }

//+------------------------------------------------------------------+
//| Calculate                                                        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(rates_total < InpATRPeriod+InpVelPeriod)
      return 0;

   double atr_buf[];
   g_atr.Calculate(rates_total, prev_calculated, open, high, low, close, atr_buf);

   int start = (prev_calculated>0) ? prev_calculated-1 : InpATRPeriod+InpVelPeriod;

   for(int i=start; i<rates_total; i++)
     {
      double atr = atr_buf[i];
      if(atr == 0)
        {
         BufVel[i]=0;
         BufSpeedPos[i]=0;
         BufSpeedNeg[i]=0;
         continue;
        }

      // 1. Velocity (Vector)
      double vel = CMetricsTools::CalculateSlope(close[i], close[i-InpVelPeriod], atr, InpVelPeriod);
      BufVel[i] = vel;

      // Color
      if(vel > InpThreshold)
         BufCol[i] = 1.0;
      else
         if(vel < -InpThreshold)
            BufCol[i] = 2.0;
         else
            BufCol[i] = 0.0;

      // 2. Speed (Scalar) - Path Length
      double path_length = 0;
      for(int k=0; k<InpVelPeriod; k++)
        {
         path_length += MathAbs(close[i-k] - close[i-k-1]);
        }
      double speed = (path_length / InpVelPeriod) / atr;

      // 3. Mirroring
      BufSpeedPos[i] = speed;
      BufSpeedNeg[i] = -speed; // Mirror for downside analysis
     }

   return rates_total;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
