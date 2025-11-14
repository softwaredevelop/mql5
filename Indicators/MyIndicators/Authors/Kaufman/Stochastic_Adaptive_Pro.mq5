//+------------------------------------------------------------------+
//|                                     Stochastic_Adaptive_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Frank Key's Variable-Length Stochastic, using Kaufman's ER."
#property description "Dynamically adjusts its period based on market trendiness."

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

#include <MyIncludes\Stochastic_Adaptive_Calculator.mqh>

//--- Input Parameters ---
input group                     "Adaptive Settings"
input int                       InpErPeriod      = 10; // Efficiency Ratio Period
input int                       InpMinStochPeriod= 5;  // Minimum Stochastic Period
input int                       InpMaxStochPeriod= 30; // Maximum Stochastic Period
input group                     "Stochastic & Price Settings"
input int                       InpSlowingPeriod = 3;
input int                       InpDPeriod       = 3;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice   = PRICE_CLOSE_STD;
input ENUM_MA_TYPE              InpDMAType       = SMA;

//--- Indicator Buffers ---
double    BufferK[], BufferD[];

//--- Global calculator object ---
CStochasticAdaptiveCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferK, INDICATOR_DATA);
   SetIndexBuffer(1, BufferD, INDICATOR_DATA);
   ArraySetAsSeries(BufferK, false);
   ArraySetAsSeries(BufferD, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CStochasticAdaptiveCalculator_HA();
   else
      g_calculator = new CStochasticAdaptiveCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpErPeriod, InpMinStochPeriod, InpMaxStochPeriod, InpSlowingPeriod, InpDPeriod, InpDMAType))
     {
      Print("Failed to create or initialize Adaptive Stochastic Calculator.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Stoch Adaptive%s(%d,%d-%d)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpErPeriod, InpMinStochPeriod, InpMaxStochPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   int draw_begin = InpErPeriod + InpMaxStochPeriod + InpSlowingPeriod + InpDPeriod;
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
   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;
   g_calculator.Calculate(rates_total, open, high, low, close, price_type, BufferK, BufferD);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
