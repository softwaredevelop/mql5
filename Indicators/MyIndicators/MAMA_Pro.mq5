//+------------------------------------------------------------------+
//|                                                      MAMA_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "John Ehlers' MESA Adaptive Moving Average (MAMA) and FAMA."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: MAMA
#property indicator_label1  "MAMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: FAMA
#property indicator_label2  "FAMA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\MAMA_Calculator.mqh>

//--- Input Parameters ---
input double                    InpFastLimit    = 0.5;   // Fast Limit for Alpha
input double                    InpSlowLimit    = 0.05;  // Slow Limit for Alpha
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferMAMA[];
double    BufferFAMA[];

//--- Global calculator object ---
CMAMACalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMAMA,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferFAMA,  INDICATOR_DATA);
   ArraySetAsSeries(BufferMAMA,  false);
   ArraySetAsSeries(BufferFAMA,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CMAMACalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MAMA HA(%.2f,%.2f)", InpFastLimit, InpSlowLimit));
     }
   else
     {
      g_calculator = new CMAMACalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MAMA(%.2f,%.2f)", InpFastLimit, InpSlowLimit));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpFastLimit, InpSlowLimit))
     {
      Print("Failed to initialize MAMA Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 50);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 50);
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

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferMAMA, BufferFAMA);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
