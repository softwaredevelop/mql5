//+------------------------------------------------------------------+
//|                                    LinearRegression_Slope_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Linear Regression Slope (Smart)."
#property description "Height = Velocity. Color = Quality (R2)."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Plot: Smart Slope Histogram
#property indicator_label1  "Slope"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors:
// 0: Weak Bull (Green)
// 1: Strong Bull (Lime)   <- High R2
// 2: Weak Bear (Maroon)
// 3: Strong Bear (Red)    <- High R2
#property indicator_color1  clrSeaGreen, clrLime, clrMaroon, clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\LinearRegression_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>

//--- Parameters
input int      InpPeriod         = 20;    // Regression Period
input int      InpATRPeriod      = 14;    // Normalization Period
input double   InpStrongR2       = 0.7;   // High Quality Threshold

//--- Buffers
double BufSlope[];
double BufColors[];

CLinearRegressionCalculator *g_calc;
CATRCalculator              *g_atr;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufSlope, INDICATOR_DATA);
   SetIndexBuffer(1, BufColors, INDICATOR_COLOR_INDEX);

   string name = StringFormat("LR-Slope(%d)", InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   g_calc = new CLinearRegressionCalculator();
   g_calc.Init(InpPeriod);

   g_atr = new CATRCalculator();
   g_atr.Init(InpATRPeriod, ATR_POINTS);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   if(CheckPointer(g_calc)==POINTER_DYNAMIC)
      delete g_calc;
   if(CheckPointer(g_atr)==POINTER_DYNAMIC)
      delete g_atr;
  }

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
   if(rates_total < MathMax(InpPeriod, InpATRPeriod))
      return 0;

   double s[], r2[], f[], atr[];
   int total = rates_total;

// Resize temp arrays
   ArrayResize(s, total);
   ArrayResize(r2, total);
   ArrayResize(f, total);
   ArrayResize(atr, total); // Actually ATR Calc handles this internally if passed but we need output buffer.

// Run Calcs
   g_calc.CalculateState(total, prev_calculated, open, high, low, close, PRICE_CLOSE, s, r2, f);
   g_atr.Calculate(total, prev_calculated, open, high, low, close, atr);

   int start = (prev_calculated > 0) ? prev_calculated - 1 : MathMax(InpPeriod, InpATRPeriod);

   for(int i = start; i < rates_total; i++)
     {
      double raw_slope = s[i];
      double current_atr = atr[i];
      double quality_r2 = r2[i];

      // Normalized Slope = Change per bar in ATR units
      // (e.g., +0.5 means price rises 0.5 ATR per bar).
      double norm_slope = 0;
      if(current_atr > 0)
         norm_slope = raw_slope / current_atr;

      BufSlope[i] = norm_slope;

      // Smart Coloring
      if(norm_slope > 0)
        {
         if(quality_r2 > InpStrongR2)
            BufColors[i] = 1.0; // Strong Bull (Lime)
         else
            BufColors[i] = 0.0; // Weak Bull (SeaGreen)
        }
      else
        {
         if(quality_r2 > InpStrongR2)
            BufColors[i] = 3.0; // Strong Bear (Red)
         else
            BufColors[i] = 2.0; // Weak Bear (Maroon)
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
