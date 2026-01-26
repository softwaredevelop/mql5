//+------------------------------------------------------------------+
//|                                       VIDYA_Adaptive_RSI_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "VIDYA using Adaptive RSI for volatility measurement."
#property description "A double-adaptive moving average."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMagenta
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
#property indicator_label1  "VIDYA (Adaptive RSI)"

#include <MyIncludes\VIDYA_Adaptive_RSI_Calculator.mqh>

//--- Input Parameters
input group                     "Adaptive RSI Settings"
input int                       InpPivotalPeriod = 14; // Pivotal RSI Period
input int                       InpVolaShort     = 5;  // Volatility Short Period
input int                       InpVolaLong      = 10; // Volatility Long Period
input ENUM_ADAPTIVE_SOURCE_RSI  InpAdaptiveSource= ADAPTIVE_SOURCE_RSI_STANDARD;

input group                     "VIDYA Settings"
input int                       InpPeriodEMA     = 20; // Base EMA Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice   = PRICE_CLOSE_STD;

//--- Buffers
double    BufferVIDYA[];

//--- Global Object
CVIDYAAdaptiveRSICalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferVIDYA, INDICATOR_DATA);
   ArraySetAsSeries(BufferVIDYA, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CVIDYAAdaptiveRSICalculator_HA();
   else
      g_calculator = new CVIDYAAdaptiveRSICalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPivotalPeriod, InpVolaShort, InpVolaLong, InpAdaptiveSource, InpPeriodEMA))
     {
      Print("Failed to initialize VIDYA Adaptive RSI Calculator.");
      return(INIT_FAILED);
     }

   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("VIDYA ARSI%s(%d, %d)", type, InpPivotalPeriod, InpPeriodEMA));

   int draw_begin = InpVolaLong + InpPivotalPeriod + InpPeriodEMA;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
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
   if(rates_total < InpPeriodEMA)
      return(0);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          BufferVIDYA);

   return(rates_total);
  }
//+------------------------------------------------------------------+
