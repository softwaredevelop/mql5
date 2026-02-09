//+------------------------------------------------------------------+
//|                                                 Velocity_Pro.mq5 |
//|                    Updated: Signed Velocity (Directional)        |
//|                    Copyright 2026, xxxxxxxx                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.00"
#property description "Signed Velocity: Normalized Speed AND Direction."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Levels
#property indicator_level1 1.0
#property indicator_level2 -1.0
#property indicator_level3 0.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Histogram
#property indicator_label1  "Velocity"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrLime, clrRed // Neutral, Up, Down
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\Metrics_Tools.mqh> // Use the shared logic

input int      InpVelPeriod   = 3;
input int      InpATRPeriod   = 14;
input double   InpThreshold   = 1.0;

double BufVel[];
double BufCol[];

CATRCalculator *g_atr;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufVel, INDICATOR_DATA);
   SetIndexBuffer(1, BufCol, INDICATOR_COLOR_INDEX);

   g_atr = new CATRCalculator();
   g_atr.Init(InpATRPeriod, ATR_POINTS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Velocity Signed");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int r) { if(CheckPointer(g_atr)==POINTER_DYNAMIC) delete g_atr; }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(rates_total < InpATRPeriod+InpVelPeriod)
      return 0;

// 1. Calc ATR for the whole range
   double atr_buf[];
   g_atr.Calculate(rates_total, prev_calculated, open, high, low, close, atr_buf);

   int start = (prev_calculated>0) ? prev_calculated-1 : InpATRPeriod+InpVelPeriod;

   for(int i=start; i<rates_total; i++)
     {
      // Calculate Slope/Velocity using Helper Logic
      // Slope between Close[i] and Close[i-Period]
      double val = CMetricsTools::CalculateSlope(close[i], close[i-InpVelPeriod], atr_buf[i], InpVelPeriod);

      BufVel[i] = val;

      if(val > InpThreshold)
         BufCol[i] = 1.0; // Lime
      else
         if(val < -InpThreshold)
            BufCol[i] = 2.0; // Red
         else
            BufCol[i] = 0.0;
     }

   return rates_total;
  }
//+------------------------------------------------------------------+
