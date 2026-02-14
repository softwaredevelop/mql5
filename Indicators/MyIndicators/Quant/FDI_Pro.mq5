//+------------------------------------------------------------------+
//|                                                      FDI_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Fractal Dimension Index (Sevcik)."
#property description "1.0 = Linear Trend, 1.5 = Random, 2.0 = Chaos."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Levels
#property indicator_level1 1.5
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot: FDI
#property indicator_label1  "FDI"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: Trend (Lime), Random/Chop (Gray)
#property indicator_color1  clrLime, clrGray
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\FDI_Calculator.mqh>

//--- Input Parameters
input int             InpPeriod      = 30;           // Analysis Period
input ENUM_APPLIED_PRICE InpPrice    = PRICE_CLOSE;  // Price Source

//--- Buffers
double BufFDI[];
double BufColor[];

//--- Calculator
CFDICalculator *g_calc;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufFDI, INDICATOR_DATA);
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX);

   string name = StringFormat("FDI(%d)", InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   g_calc = new CFDICalculator();
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

   g_calc.Calculate(rates_total, prev_calculated, InpPrice, open, high, low, close, BufFDI);

// Color Logic
   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpPeriod;

   for(int i = start; i < rates_total; i++)
     {
      double fdi = BufFDI[i];

      if(fdi < 1.5)
         BufColor[i] = 0.0; // Lime (Trend)
      else
         BufColor[i] = 1.0; // Gray (Chaos)
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
