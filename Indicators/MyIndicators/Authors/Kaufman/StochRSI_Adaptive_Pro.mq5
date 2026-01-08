//+------------------------------------------------------------------+
//|                                      StochRSI_Adaptive_Pro.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Stochastic Oscillator applied to Adaptive RSI."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_level1 10.0
#property indicator_level2 20.0
#property indicator_level3 50.0
#property indicator_level4 80.0
#property indicator_level5 90.0
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

#include <MyIncludes\StochRSI_Adaptive_Calculator.mqh>

//--- Input Parameters ---
input group                     "Adaptive RSI Settings"
input int                       InpPivotalPeriod = 14;
input int                       InpVolaShort     = 5;
input int                       InpVolaLong      = 10;
input ENUM_ADAPTIVE_SOURCE_RSI  InpAdaptiveSource= ADAPTIVE_SOURCE_RSI_STANDARD;

input group                     "Stochastic Settings"
input int                       InpKPeriod       = 14;
input int                       InpSlowingPeriod = 3;
input ENUM_MA_TYPE              InpSlowingMAType = SMA;
input int                       InpDPeriod       = 3;
input ENUM_MA_TYPE              InpDMAType       = SMA;

input group                     "Price Source"
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice   = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferK[], BufferD[];

//--- Global calculator object ---
CStochRSIAdaptiveCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferK, INDICATOR_DATA);
   SetIndexBuffer(1, BufferD, INDICATOR_DATA);
   ArraySetAsSeries(BufferK, false);
   ArraySetAsSeries(BufferD, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CStochRSIAdaptiveCalculator_HA();
   else
      g_calculator = new CStochRSIAdaptiveCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPivotalPeriod, InpVolaShort, InpVolaLong, InpAdaptiveSource,
                         InpKPeriod, InpSlowingPeriod, InpSlowingMAType, InpDPeriod, InpDMAType))
     {
      Print("Failed to initialize StochRSI Adaptive Calculator.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("StochRSI Adaptive%s(%d)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpPivotalPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   int draw_begin = InpVolaLong + InpPivotalPeriod + InpKPeriod + InpSlowingPeriod + InpDPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;
   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferK, BufferD);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
