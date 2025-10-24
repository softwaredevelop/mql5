//+------------------------------------------------------------------+
//|                                                  SineWMA_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00"
#property description "Professional Sine Weighted Moving Average with selectable"
#property description "price source (Standard and Heikin Ashi)."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Include the calculator engine ---
#include <MyIncludes\SineWMA_Calculator.mqh>

//--- Plot 1: Sine WMA Line
#property indicator_label1  "Sine WMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumTurquoise
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Input Parameters ---
input int                       InpPeriod      = 21;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferWMA[];

//--- Global calculator object (as a base class pointer) ---
CSineWMACalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferWMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferWMA, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CSineWMACalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("SineWMA HA(%d)", InpPeriod));
     }
   else
     {
      g_calculator = new CSineWMACalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("SineWMA(%d)", InpPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod))
     {
      Print("Failed to initialize Sine WMA Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod - 1);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function.                             |
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

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferWMA);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
