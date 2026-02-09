//+------------------------------------------------------------------+
//|                                                 Velocity_Pro.mq5 |
//|                    Velocity (Vector) vs Speed (Scalar)           |
//|                    Copyright 2026, xxxxxxxx                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00"
#property description "Displays Velocity (Histogram) and Speed (Line)."
#property description "Velocity = Directional. Speed = Distance Traveled."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

//--- Levels
#property indicator_level1 1.0
#property indicator_level2 -1.0
#property indicator_level3 0.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: Velocity Histogram
#property indicator_label1  "Velocity (Vector)"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrLime, clrRed // Neutral, Up, Down
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Speed Line (Optional)
#property indicator_label2  "Speed (Scalar)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGold
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\Metrics_Tools.mqh>

//--- Parameters
input int               InpVelPeriod   = 3;           // Lookback Period
input int               InpATRPeriod   = 14;          // Normalization ATR
input double            InpThreshold   = 1.0;         // High Velocity Threshold
input bool              InpShowSpeed   = true;        // Show Scalar Speed Line?

//--- Buffers
double BufVel[];
double BufCol[];
double BufSpeed[];

CATRCalculator *g_atr;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufVel, INDICATOR_DATA);
   SetIndexBuffer(1, BufCol, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufSpeed, INDICATOR_DATA);

// Hide Speed line if requested
   if(!InpShowSpeed)
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);

   g_atr = new CATRCalculator();
   g_atr.Init(InpATRPeriod, ATR_POINTS);

   string name = StringFormat("Velocity(%d)", InpVelPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int r) { if(CheckPointer(g_atr)==POINTER_DYNAMIC) delete g_atr; }

//+------------------------------------------------------------------+
//| Calculate                                                        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(rates_total < InpATRPeriod+InpVelPeriod)
      return 0;

// 1. Calc ATR
   double atr_buf[];
   g_atr.Calculate(rates_total, prev_calculated, open, high, low, close, atr_buf);

   int start = (prev_calculated>0) ? prev_calculated-1 : InpATRPeriod+InpVelPeriod;

   for(int i=start; i<rates_total; i++)
     {
      double atr = atr_buf[i];
      if(atr == 0)
        {
         BufVel[i]=0;
         BufSpeed[i]=0;
         continue;
        }

      // --- A. Velocity (Vector) ---
      // (Close[i] - Close[i-N]) / (N * ATR)
      double vel = CMetricsTools::CalculateSlope(close[i], close[i-InpVelPeriod], atr, InpVelPeriod);
      BufVel[i] = vel;

      // Color Logic for Velocity
      if(vel > InpThreshold)
         BufCol[i] = 1.0;      // Lime
      else
         if(vel < -InpThreshold)
            BufCol[i] = 2.0;// Red
         else
            BufCol[i] = 0.0;                        // Gray

      // --- B. Speed (Scalar) ---
      // Avg(Abs(Close[k] - Close[k-1])) / ATR
      // Path Length over period
      double path_length = 0;
      for(int k=0; k<InpVelPeriod; k++)
        {
         path_length += MathAbs(close[i-k] - close[i-k-1]);
        }
      double avg_step = path_length / InpVelPeriod;
      BufSpeed[i] = avg_step / atr;
     }

   return rates_total;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
