//+------------------------------------------------------------------+
//|                                              CyclePeriod_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "John Ehlers' Dominant Cycle Period Measurement."
#property description "Use this to tune the MADH indicator."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "Cycle Period"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrOrange
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// Typical cycle range
#property indicator_minimum 6
#property indicator_maximum 50

#include <MyIncludes\CyclePeriod_Calculator.mqh>

//--- Indicator Buffers ---
double    BufferPeriod[];

//--- Global calculator object ---
CCyclePeriodCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferPeriod, INDICATOR_DATA);
   ArraySetAsSeries(BufferPeriod, false);

   g_calculator = new CCyclePeriodCalculator();

   if(!g_calculator.Init())
      return(INIT_FAILED);

   IndicatorSetString(INDICATOR_SHORTNAME, "Dominant Cycle Period");
   IndicatorSetInteger(INDICATOR_DIGITS, 0); // Periods are integers usually

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Use Median Price implicitly
   g_calculator.Calculate(rates_total, prev_calculated, PRICE_MEDIAN, open, high, low, close, BufferPeriod);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
