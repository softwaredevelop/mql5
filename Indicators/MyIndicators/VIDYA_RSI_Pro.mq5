//+------------------------------------------------------------------+
//|                                                VIDYA_RSI_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "VIDYA that uses RSI for volatility measurement. With selectable"
#property description "price source (Standard and Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumOrchid
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label1  "VIDYA (RSI)"

//--- Include the calculator engine ---
#include <MyIncludes\VIDYA_RSI_Calculator.mqh>

//--- Input Parameters ---
input int                       InpPeriodRSI    = 14;
input int                       InpPeriodEMA    = 20;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferVIDYA[];

//--- Global calculator object (as a base class pointer) ---
CVIDYARSICalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferVIDYA, INDICATOR_DATA);
   ArraySetAsSeries(BufferVIDYA, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CVIDYARSICalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("VIDYA RSI HA(%d,%d)", InpPeriodRSI, InpPeriodEMA));
     }
   else
     {
      g_calculator = new CVIDYARSICalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("VIDYA RSI(%d,%d)", InpPeriodRSI, InpPeriodEMA));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriodRSI, InpPeriodEMA))
     {
      Print("Failed to create or initialize VIDYA RSI Calculator object.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriodRSI + InpPeriodEMA);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferVIDYA);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
