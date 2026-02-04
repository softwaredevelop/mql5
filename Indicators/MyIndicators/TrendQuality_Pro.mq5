//+------------------------------------------------------------------+
//|                                             TrendQuality_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Kaufman's Efficiency Ratio (ER)."
#property description "Measures Trend Quality vs Noise (0.0 to 1.0)."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Levels
#property indicator_level1 0.3
#property indicator_level2 0.6
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT
#property indicator_minimum 0.0
#property indicator_maximum 1.0

//--- Plot: ER Line (Colored)
#property indicator_label1  "Trend Quality"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrDodgerBlue, clrGold // Noise, Trend, SuperTrend
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\EfficiencyRatio_Calculator.mqh>

//--- Input Parameters
input int               InpPeriod      = 10;          // Calculation Period
input double            InpThreshold   = 0.30;        // Trend Threshold (Purple Line)
input double            InpStrongLevel = 0.60;        // Strong Trend Level (Gold Line)
input ENUM_APPLIED_PRICE InpPrice      = PRICE_CLOSE; // Applied Price

//--- Buffers
double BufferER[];
double BufferColors[]; // 0=Noise, 1=Trend, 2=Strong

//--- Global Object
CEfficiencyRatioCalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferER, INDICATOR_DATA);
   SetIndexBuffer(1, BufferColors, INDICATOR_COLOR_INDEX);

   string name = StringFormat("TrendQuality(%d)", InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   g_calculator = new CEfficiencyRatioCalculator();
   if(!g_calculator.Init(InpPeriod))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) == POINTER_DYNAMIC)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
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

// Calculation
   g_calculator.Calculate(rates_total, prev_calculated, InpPrice, open, high, low, close, BufferER);

// Coloring Logic
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start_index; i < rates_total; i++)
     {
      double er = BufferER[i];

      if(er > InpStrongLevel)
         BufferColors[i] = 2.0; // Gold (Super Trend)
      else
         if(er > InpThreshold)
            BufferColors[i] = 1.0; // Blue (Trending)
         else
            BufferColors[i] = 0.0; // Gray (Chop/Noise)
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
