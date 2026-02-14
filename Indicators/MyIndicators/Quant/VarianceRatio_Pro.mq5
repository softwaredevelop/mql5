//+------------------------------------------------------------------+
//|                                            VarianceRatio_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Variance Ratio (Lo-MacKinlay)."
#property description "Ratio > 1: Trend. Ratio < 1: Mean Reversion."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Levels
#property indicator_level1 1.0
#property indicator_level2 1.3
#property indicator_level3 0.7
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot: VR Histogram
#property indicator_label1  "VR"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: MeanRev(Blue), Random(Gray), Trend(Lime)
#property indicator_color1  clrDeepSkyBlue, clrGray, clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\VarianceRatio_Calculator.mqh>

//--- Input Parameters
input int      InpWindow         = 64;    // Sampling Window (N)
input int      InpLag            = 2;     // Lag Period (q) - Usually 2
input ENUM_APPLIED_PRICE InpPrice= PRICE_CLOSE;

//--- Buffers
double BufVR[];
double BufColors[];

//--- Calculator
CVarianceRatioCalculator *g_calc;
double g_price[];

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufVR, INDICATOR_DATA);
   SetIndexBuffer(1, BufColors, INDICATOR_COLOR_INDEX);

   string name = StringFormat("VR(%d,%d)", InpWindow, InpLag);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   g_calc = new CVarianceRatioCalculator();
   if(!g_calc.Init(InpWindow, InpLag))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   if(CheckPointer(g_calc)==POINTER_DYNAMIC)
      delete g_calc;
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
   if(rates_total < InpWindow + InpLag + 10)
      return 0;

// Calc
   g_calc.Calculate(rates_total, prev_calculated, InpPrice, open, high, low, close, BufVR);

// Color Logic
   int loop_start = (prev_calculated > 0) ? prev_calculated - 1 : InpWindow + InpLag;

   for(int i = loop_start; i < rates_total; i++)
     {
      double vr = BufVR[i];

      // Thresholds:
      // > 1.1 -> Strong Trend (Lime)
      // < 0.9 -> Mean Reversion (Blue)
      // 0.9 - 1.1 -> Random Walk (Gray)

      if(vr > 1.1)
         BufColors[i] = 2.0; // Lime
      else
         if(vr < 0.9)
            BufColors[i] = 0.0; // Blue
         else
            BufColors[i] = 1.0; // Gray
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
