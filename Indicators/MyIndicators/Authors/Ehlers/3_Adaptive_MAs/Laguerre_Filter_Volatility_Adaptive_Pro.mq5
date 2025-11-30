//+------------------------------------------------------------------+
//|                        Laguerre_Filter_Volatility_Adaptive_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Adaptive Laguerre Filter based on Volatility (MotiveWave method)."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMagenta
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label1  "Vol-Adaptive Laguerre"

#include <MyIncludes\Laguerre_Filter_Volatility_Calculator.mqh>

//--- Input Parameters ---
input int                       InpPeriod1      = 20; // Period for Diff Range
input int                       InpPeriod2      = 5;  // Period for Alpha Median
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferFilter[];

//--- Global calculator object ---
CLaguerreFilterVolatilityCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferFilter, INDICATOR_DATA);
   ArraySetAsSeries(BufferFilter, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CLaguerreFilterVolatilityCalculator_HA();
   else
      g_calculator = new CLaguerreFilterVolatilityCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod1, InpPeriod2))
     {
      Print("Failed to initialize Calculator.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Vol-Adaptive Laguerre%s(%d,%d)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpPeriod1, InpPeriod2));
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, MathMax(InpPeriod1, InpPeriod2));
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
int OnCalculate(const int rates_total, const int prev_calculated, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferFilter);

   return(rates_total);
  }
//+------------------------------------------------------------------+
