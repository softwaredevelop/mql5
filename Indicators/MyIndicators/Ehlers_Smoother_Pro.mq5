//+------------------------------------------------------------------+
//|                                         Ehlers_Smoother_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.10" // Refactored calculation for definition-true stability
#property description "John Ehlers' SuperSmoother and UltimateSmoother filters."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "Smoother"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlueViolet
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>

//--- Input Parameters ---
input ENUM_SMOOTHER_TYPE        InpSmootherType = SUPERSMOOTHER; // Type of smoother
input int                       InpPeriod       = 20;            // Critical Period for the filter
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferFilter[];

//--- Global calculator object ---
CEhlersSmootherCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferFilter,  INDICATOR_DATA);
   ArraySetAsSeries(BufferFilter,  false);

   string name = (InpSmootherType == SUPERSMOOTHER) ? "SuperSmoother" : "UltimateSmoother";

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CEhlersSmootherCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("%s HA(%d)", name, InpPeriod));
     }
   else
     {
      g_calculator = new CEhlersSmootherCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("%s(%d)", name, InpPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpSmootherType))
     {
      Print("Failed to initialize Ehlers Smoother Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 3); // Draw from the 4th bar (index 3)
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
