//+------------------------------------------------------------------+
//|                                          Autocorrelation_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Lag-1 Serial Correlation."
#property description "Positive = Trend / Momentum. Negative = Mean Reversion."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Levels
#property indicator_level1 0.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT
#property indicator_minimum -1.0
#property indicator_maximum 1.0

// Plot: Histogram
#property indicator_label1  "AutoCorr"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: MeanRev(Red), Random(Gray), Trend(Green)
#property indicator_color1  clrCrimson, clrGray, clrSpringGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\Autocorrelation_Calculator.mqh>

//--- Parameters
input int             InpPeriod      = 20;           // Window Size
input double          InpThreshold   = 0.1;          // Significance Threshold
input ENUM_APPLIED_PRICE InpPrice    = PRICE_CLOSE;

//--- Buffers
double BufAC[];
double BufColors[]; // 0=Neg, 1=Neu, 2=Pos

CAutocorrelationCalculator *g_calc;
double g_price[];

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufAC, INDICATOR_DATA);
   SetIndexBuffer(1, BufColors, INDICATOR_COLOR_INDEX);

   string name = StringFormat("AutoCorr(%d)", InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   g_calc = new CAutocorrelationCalculator();
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
   if(rates_total < InpPeriod + 5)
      return 0;

// Calc
   g_calc.Calculate(rates_total, prev_calculated, InpPrice, open, high, low, close, BufAC);

// Color Logic
   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpPeriod;

   for(int i = start; i < rates_total; i++)
     {
      double ac = BufAC[i];

      if(ac > InpThreshold)
         BufColors[i] = 2.0; // Green (Momentum)
      else
         if(ac < -InpThreshold)
            BufColors[i] = 0.0; // Red (Mean Rev)
         else
            BufColors[i] = 1.0; // Gray (Random)
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
