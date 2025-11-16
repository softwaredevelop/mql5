//+------------------------------------------------------------------+
//|                               Stochastic_DoubleSmoothed_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "William Blau's Double Smoothed Stochastic."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_level1 20.0
#property indicator_level2 50.0
#property indicator_level3 80.0
#property indicator_minimum 0.0
#property indicator_maximum 100.0

#property indicator_label1  "%K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label2  "%D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrCoral
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\Stochastic_DoubleSmoothed_Calculator.mqh>

//--- Input Parameters ---
input group                     "Stochastic Settings"
input int                       InpStochPeriod   = 5;  // Stochastic Period (q)
input int                       InpSmoothPeriod1 = 3;  // 1st Smoothing Period (r)
input int                       InpSmoothPeriod2 = 3;  // 2nd Smoothing Period (s)
input int                       InpSignalPeriod  = 3;  // Signal Line Period
input group                     "Price Source"
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice   = PRICE_CLOSE_STD; // Note: UO uses H,L,C, so this is a simplification

//--- Indicator Buffers ---
double    BufferK[], BufferD[];

//--- Global calculator object ---
CStochasticDoubleSmoothedCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferK, INDICATOR_DATA);
   SetIndexBuffer(1, BufferD, INDICATOR_DATA);
   ArraySetAsSeries(BufferK, false);
   ArraySetAsSeries(BufferD, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CStochasticDoubleSmoothedCalculator_HA();
   else
      g_calculator = new CStochasticDoubleSmoothedCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpStochPeriod, InpSmoothPeriod1, InpSmoothPeriod2, InpSignalPeriod))
     {
      Print("Failed to create or initialize Double Smoothed Stochastic Calculator.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("DS Stoch%s(%d,%d,%d)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpStochPeriod, InpSmoothPeriod1, InpSmoothPeriod2));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   int draw_begin = InpStochPeriod + InpSmoothPeriod1 + InpSmoothPeriod2 + InpSignalPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;
// The calculator handles its own price source logic
   g_calculator.Calculate(rates_total, open, high, low, close, BufferK, BufferD);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
