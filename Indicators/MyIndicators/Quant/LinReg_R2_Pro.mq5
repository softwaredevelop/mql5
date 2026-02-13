//+------------------------------------------------------------------+
//|                                              LinReg_R2_Pro.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Linear Regression R-Squared & Slope."
#property description "R2 measures Trend Integrity. Slope measures Direction."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

// Levels for R2
#property indicator_level1 0.7
#property indicator_level2 0.3
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT
#property indicator_maximum 1.0
#property indicator_minimum 0.0

// Plot 1: R-Squared (Histogram)
#property indicator_label1  "R-Squared"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: No Trend (Gray), Weak (Orange), Strong (Lime)
#property indicator_color1  clrGray, clrOrange, clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\LinearRegression_Calculator.mqh>

//--- Parameters
input int      InpPeriod         = 20;    // Regression Period
input double   InpTrendLevel     = 0.7;   // Strong Trend Level (R2)

//--- Buffers
double BufR2[];
double BufColors[];
double BufSlope[]; // Calculations only (visible in Data Window)

CLinearRegressionCalculator *g_calc;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufR2, INDICATOR_DATA);
   SetIndexBuffer(1, BufColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufSlope, INDICATOR_CALCULATIONS); // Not drawn

   string name = StringFormat("LinReg R2(%d)", InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

   g_calc = new CLinearRegressionCalculator();
   if(!g_calc.Init(InpPeriod))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int r) { if(CheckPointer(g_calc)==POINTER_DYNAMIC) delete g_calc; }

//+------------------------------------------------------------------+
//| Calculate                                                        |
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
   if(rates_total < InpPeriod)
      return 0;

   double s[], r2[], f[];
   ArrayResize(s, rates_total);
   ArrayResize(r2, rates_total);
   ArrayResize(f, rates_total);

// Run Engine
   g_calc.CalculateState(rates_total, prev_calculated, open, high, low, close, PRICE_CLOSE, s, r2, f);

   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpPeriod;

   for(int i = start; i < rates_total; i++)
     {
      double val = r2[i];
      BufR2[i] = val;
      BufSlope[i] = s[i]; // Raw slope

      // Color Logic
      if(val >= InpTrendLevel)
         BufColors[i] = 2.0; // Lime (Strong)
      else
         if(val <= 0.3)
            BufColors[i] = 0.0; // Gray (Noise)
         else
            BufColors[i] = 1.0; // Orange (Weak/Transition)
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
