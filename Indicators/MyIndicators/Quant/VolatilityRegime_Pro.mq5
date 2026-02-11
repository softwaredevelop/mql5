//+------------------------------------------------------------------+
//|                                         VolatilityRegime_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Volatility Regime (Expansion vs Contraction)."
#property description "Ratio of Fast ATR / Slow ATR."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Levels
#property indicator_level1 1.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot: Regime Histogram
#property indicator_label1  "Vola Ratio"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Color Index: 0=Contracting (Gray), 1=Expanding (Lime)
#property indicator_color1  clrGray, clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\ATR_Calculator.mqh>

//--- Input Parameters
input int      InpPeriodFast     = 5;     // Short-term Volatility
input int      InpPeriodSlow     = 50;    // Long-term Baseline
input double   InpThreshold      = 1.0;   // Expansion Threshold

//--- Buffers
double BufRatio[];
double BufColors[];

//--- Calculators
CATRCalculator *g_atr_fast;
CATRCalculator *g_atr_slow;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufRatio, INDICATOR_DATA);
   SetIndexBuffer(1, BufColors, INDICATOR_COLOR_INDEX);

   string name = StringFormat("VolaRegime(%d/%d)", InpPeriodFast, InpPeriodSlow);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   g_atr_fast = new CATRCalculator();
   if(!g_atr_fast.Init(InpPeriodFast, ATR_POINTS))
      return INIT_FAILED;

   g_atr_slow = new CATRCalculator();
   if(!g_atr_slow.Init(InpPeriodSlow, ATR_POINTS))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   if(CheckPointer(g_atr_fast)==POINTER_DYNAMIC)
      delete g_atr_fast;
   if(CheckPointer(g_atr_slow)==POINTER_DYNAMIC)
      delete g_atr_slow;
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
   if(rates_total < InpPeriodSlow)
      return 0;

   double atr_f[], atr_s[];

// Calc both ATRs
   g_atr_fast.Calculate(rates_total, prev_calculated, open, high, low, close, atr_f);
   g_atr_slow.Calculate(rates_total, prev_calculated, open, high, low, close, atr_s);

   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpPeriodSlow;

   for(int i = start; i < rates_total; i++)
     {
      double fast = atr_f[i];
      double slow = atr_s[i];

      if(slow > 0.00000001)
        {
         double ratio = fast / slow;
         BufRatio[i] = ratio;

         // Coloring Legend:
         // Gray (0): Contraction (Ratio < 1.0) -> Market is sleeping/dying.
         // Lime (1): Expansion (Ratio > 1.0)   -> Market is moving.

         if(ratio >= InpThreshold)
            BufColors[i] = 1.0; // Expansion
         else
            BufColors[i] = 0.0; // Contraction
        }
      else
        {
         BufRatio[i] = 1.0;
         BufColors[i] = 0.0;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
