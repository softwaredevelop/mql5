//+------------------------------------------------------------------+
//|                                  Laguerre_Filter_Adaptive_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "John Ehlers' Adaptive Laguerre Filter. The filter's coefficient (gamma)"
#property description "is dynamically adjusted based on the measured market cycle period."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumOrchid
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label1  "Adaptive Laguerre"

//--- Include the calculator engine ---
#include <MyIncludes\Laguerre_Filter_Adaptive_Calculator.mqh>

//--- Input Parameters ---
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferFilter[];

//--- Global calculator object (as a base class pointer) ---
CLaguerreFilterAdaptiveCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferFilter, INDICATOR_DATA);
   ArraySetAsSeries(BufferFilter, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CLaguerreFilterAdaptiveCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, "Adaptive Laguerre HA");
     }
   else
     {
      g_calculator = new CLaguerreFilterAdaptiveCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, "Adaptive Laguerre");
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init())
     {
      Print("Failed to create or initialize Adaptive Laguerre Filter Calculator object.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 10); // Needs a longer warmup period
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferFilter);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
