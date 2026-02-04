//+------------------------------------------------------------------+
//|                                        ZScore_Distance_Pro.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Statistical Z-Score Oscillator."
#property description "Measures deviation from the mean in Sigma units."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Levels
#property indicator_level1 0.0
#property indicator_level2 2.0
#property indicator_level3 -2.0
#property indicator_level4 3.0
#property indicator_level5 -3.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot: Z-Score Histogram (Colored)
#property indicator_label1  "Z-Score"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrRed, clrLime  // Normal, Overbought, Oversold
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\ZScore_Calculator.mqh>

//--- Input Parameters
input int               InpPeriod      = 20;          // Lookback Period
input ENUM_APPLIED_PRICE InpPrice      = PRICE_CLOSE; // Applied Price

//--- Buffers
double BufferZ[];
double BufferColors[]; // 0=Gray, 1=Red (+), 2=Lime (-)

//--- Global Object
CZScoreCalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferZ, INDICATOR_DATA);
   SetIndexBuffer(1, BufferColors, INDICATOR_COLOR_INDEX);

   string name = StringFormat("ZScore(%d)", InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2); // Z-Score usually 2 decimals (e.g. 1.54)

   g_calculator = new CZScoreCalculator();
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
   g_calculator.Calculate(rates_total, prev_calculated, InpPrice, open, high, low, close, BufferZ);

// Coloring Logic (Visual Wrapper only)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start_index; i < rates_total; i++)
     {
      double z = BufferZ[i];

      // Color Logic:
      // > 2.0  -> Red (Extreme High)
      // < -2.0 -> Lime (Extreme Low)
      // Else   -> Gray (Normal)
      if(z > 2.0)
         BufferColors[i] = 1.0;       // Red
      else
         if(z < -2.0)
            BufferColors[i] = 2.0; // Lime
         else
            BufferColors[i] = 0.0;              // Gray
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
