//+------------------------------------------------------------------+
//|                                              VIDYA_Stdev_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Tushar Chande's original VIDYA using Standard Deviation ratio."
#property description "Adapts its speed based on relative volatility."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "VIDYA (Stdev)"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDarkOrange
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\VIDYA_Stdev_Calculator.mqh>

//--- Input Parameters ---
input int                       InpVidyaPeriod    = 9;     // Base VIDYA Period
input int                       InpStdevShort     = 9;     // Short-term Stdev Period (n)
input int                       InpStdevLong      = 30;    // Long-term Stdev Period (m)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferVIDYA[];

//--- Global calculator object ---
CVIDYAStdevCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferVIDYA,  INDICATOR_DATA);
   ArraySetAsSeries(BufferVIDYA,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CVIDYAStdevCalculator_HA();
   else
      g_calculator = new CVIDYAStdevCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpVidyaPeriod, InpStdevShort, InpStdevLong))
     {
      Print("Failed to initialize VIDYA Stdev Calculator.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("VIDYA Stdev%s(%d,%d,%d)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpVidyaPeriod, InpStdevShort, InpStdevLong));
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpStdevLong);
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
