//+------------------------------------------------------------------+
//|                                                  Entropy_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Sample Entropy (SampEn)."
#property description "Measures market regularity. Low = Trend/Squeeze."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Levels (Approximate for m=2, r=0.2)
// Values usually range 0.5 to 2.5
#property indicator_level1 1.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot: Entropy Line
#property indicator_label1  "SampEn"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: Low/Order (Lime), High/Chaos (Gray)
#property indicator_color1  clrLime, clrGray
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\Entropy_Calculator.mqh>

//--- Settings
input int               InpPeriod      = 50;    // Analysis Window (N)
input int               InpDim         = 2;     // Pattern Length (m)
input double            InpTol         = 0.2;   // Tolerance (r * StdDev)
input ENUM_APPLIED_PRICE InpPrice      = PRICE_CLOSE;

//--- Buffers
double BufEn[];
double BufCol[];

CEntropyCalculator *g_calc;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufEn, INDICATOR_DATA);
   SetIndexBuffer(1, BufCol, INDICATOR_COLOR_INDEX);

   string name = StringFormat("Entropy(%d)", InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 3);

   g_calc = new CEntropyCalculator();
   if(!g_calc.Init(InpPeriod, InpDim, InpTol))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int r) { if(CheckPointer(g_calc)==POINTER_DYNAMIC) delete g_calc; }

//+------------------------------------------------------------------+
//| Calculate                                                        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(rates_total < InpPeriod + 5)
      return 0;

   g_calc.Calculate(rates_total, prev_calculated, InpPrice, open, high, low, close, BufEn);

   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpPeriod;

   for(int i = start; i < rates_total; i++)
     {
      double en = BufEn[i];
      // Interpretation Thresholds:
      // < 1.0 (or below avg): Organized market (Trend or Range building).
      // > 1.5: Disorganized/Noisy.

      if(en < 1.0)
         BufCol[i] = 0.0; // Lime (Order)
      else
         if(en > 1.5)
            BufCol[i] = 1.0; // Gray (Chaos)
         else
            BufCol[i] = 1.0; // Gray/Transition
     }
   return rates_total;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
