//+------------------------------------------------------------------+
//|                                                  VScore_Pro.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "V-Score (VWAP Z-Score)."
#property description "Distance from VWAP in Standard Deviations."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Levels
#property indicator_level1 2.0
#property indicator_level2 -2.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot: Histogram
#property indicator_label1  "V-Score"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: Normal(Gray), High(Orange), Low(Blue)
#property indicator_color1  clrGray, clrOrangeRed, clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\VScore_Calculator.mqh>

//--- Input Parameters
input int              InpPeriod         = 20;            // StdDev Lookback
input ENUM_VWAP_PERIOD InpVWAPReset      = PERIOD_SESSION; // VWAP Anchor

//--- Buffers
double BufV[];
double BufCol[];

CVScoreCalculator *g_calc;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufV, INDICATOR_DATA);
   SetIndexBuffer(1, BufCol, INDICATOR_COLOR_INDEX);

   string name = StringFormat("V-Score(%d)", InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

   g_calc = new CVScoreCalculator();
   if(!g_calc.Init(InpPeriod, InpVWAPReset))
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

   g_calc.Calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, BufV);

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
     {
      double v = BufV[i];
      if(v >= 2.0)
         BufCol[i] = 1.0;      // Red
      else
         if(v <= -2.0)
            BufCol[i] = 2.0; // Blue
         else
            BufCol[i] = 0.0;               // Gray
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
