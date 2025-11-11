//+------------------------------------------------------------------+
//|                                 MACD_SuperSmoother_Line_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Plots only the MACD Line from the SuperSmoother MACD."
#property description "Designed for applying external moving averages for testing."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: MACD Line
#property indicator_label1  "MACD Line"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\MACD_SuperSmoother_Line_Calculator.mqh>

//--- Input Parameters ---
input int                       InpFastPeriod   = 12;
input int                       InpSlowPeriod   = 26;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferMACDLine[];

//--- Global calculator object ---
CMACDSuperSmootherLineCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMACDLine, INDICATOR_DATA);
   ArraySetAsSeries(BufferMACDLine, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMACDSuperSmootherLineCalculator_HA();
   else
      g_calculator = new CMACDSuperSmootherLineCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpFastPeriod, InpSlowPeriod))
     {
      Print("Failed to create or initialize MACD SuperSmoother Line Calculator.");
      return(INIT_FAILED);
     }

   string short_name = StringFormat("MACD SS Line%s(%d,%d)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpFastPeriod, InpSlowPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpSlowPeriod);
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
   g_calculator.Calculate(rates_total, open, high, low, close, price_type, BufferMACDLine);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
