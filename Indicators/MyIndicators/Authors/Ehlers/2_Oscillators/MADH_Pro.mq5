//+------------------------------------------------------------------+
//|                                                     MADH_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "John Ehlers' MADH (Moving Average Difference - Hann) indicator."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "MADH"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrYellow
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_level1 0.0
#property indicator_levelstyle STYLE_SOLID
#property indicator_levelcolor clrWhite

#include <MyIncludes\MADH_Calculator.mqh>

//--- Input Parameters ---
input int                       InpShortLength    = 8;     // Short HWMA Length
input int                       InpDominantCycle  = 27;    // Dominant Cycle Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferMADH[];

//--- Global calculator object ---
CMADHCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMADH,  INDICATOR_DATA);
   ArraySetAsSeries(BufferMADH,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CMADHCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MADH HA(%d,%d)", InpShortLength, InpDominantCycle));
     }
   else
     {
      g_calculator = new CMADHCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MADH(%d,%d)", InpShortLength, InpDominantCycle));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpShortLength, InpDominantCycle))
     {
      Print("Failed to initialize MADH Calculator.");
      return(INIT_FAILED);
     }

   int long_len = InpShortLength + (int)round(InpDominantCycle / 2.0);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, long_len);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

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

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferMADH);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
