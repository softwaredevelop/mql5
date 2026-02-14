//+------------------------------------------------------------------+
//|                                                      VHF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Vertical Horizontal Filter (Adam White)."
#property description "Determines Trend vs Congestion phase."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Levels
#property indicator_level1 0.3
#property indicator_level2 0.4
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot: VHF Line (Colored)
#property indicator_label1  "VHF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: Chop(Gray), Trending(Blue), Strong(Gold)
#property indicator_color1  clrGray, clrDodgerBlue, clrGold
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\VHF_Calculator.mqh>

//--- Input Parameters
input int               InpPeriod      = 28;          // VHF Period (Standard is 28)
input ENUM_APPLIED_PRICE InpPrice      = PRICE_CLOSE; // Price Source
input ENUM_VHF_MODE     InpMode        = VHF_MODE_CLOSE_ONLY; // Default: Classic

//--- Buffers
double BufVHF[];
double BufColor[];

//--- Global Object
CVHFCalculator *g_calc;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufVHF, INDICATOR_DATA);
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX);

   string name = StringFormat("VHF(%d)", InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   g_calc = new CVHFCalculator();
   if(!g_calc.Init(InpPeriod, InpMode))
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

   g_calc.Calculate(rates_total, prev_calculated, InpPrice, open, high, low, close, BufVHF);

// Color Logic
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
     {
      double v = BufVHF[i];

      if(v > 0.40)
         BufColor[i] = 2.0; // Gold (Strong Trend)
      else
         if(v > 0.30)
            BufColor[i] = 1.0; // Blue (Trend Start)
         else
            BufColor[i] = 0.0; // Gray (Chop)
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
