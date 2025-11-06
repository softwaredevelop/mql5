//+------------------------------------------------------------------+
//|                                                    VIDYA_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00"
#property description "Professional Variable Index Dynamic Average (VIDYA) with selectable"
#property description "price source (Standard and Heikin Ashi)."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label1  "VIDYA"

#include <MyIncludes\VIDYA_Calculator.mqh>

input int                       InpPeriodCMO    = 9;
input int                       InpPeriodEMA    = 12;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

double    BufferVIDYA[];
CVIDYACalculator *g_calculator;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferVIDYA, INDICATOR_DATA);
   ArraySetAsSeries(BufferVIDYA, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CVIDYACalculator_HA();
   else
      g_calculator = new CVIDYACalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriodCMO, InpPeriodEMA))
     {
      Print("Failed to create or initialize VIDYA Calculator object.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("VIDYA%s(%d,%d)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpPeriodCMO, InpPeriodEMA));
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriodCMO + InpPeriodEMA);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;
   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- This call automatically resolves to the single-buffer version ---
   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferVIDYA);
   return(rates_total);
  }
//+------------------------------------------------------------------+
