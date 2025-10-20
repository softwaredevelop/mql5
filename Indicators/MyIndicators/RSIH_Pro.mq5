//+------------------------------------------------------------------+
//|                                                     RSIH_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "John Ehlers' Improved RSI with Hann Windowing (RSIH)."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "RSIH"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrYellow
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_minimum -1.1
#property indicator_maximum 1.1
#property indicator_level1 0.5
#property indicator_level2 0.0
#property indicator_level3 -0.5
#property indicator_levelcolor clrGray
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\RSIH_Calculator.mqh>

enum ENUM_APPLIED_PRICE_HA_ALL
  {
   PRICE_HA_CLOSE    = -1, PRICE_HA_OPEN     = -2, PRICE_HA_HIGH     = -3, PRICE_HA_LOW      = -4,
   PRICE_HA_MEDIAN   = -5, PRICE_HA_TYPICAL  = -6, PRICE_HA_WEIGHTED = -7,
   PRICE_CLOSE_STD   = PRICE_CLOSE, PRICE_OPEN_STD    = PRICE_OPEN, PRICE_HIGH_STD    = PRICE_HIGH,
   PRICE_LOW_STD     = PRICE_LOW, PRICE_MEDIAN_STD  = PRICE_MEDIAN, PRICE_TYPICAL_STD = PRICE_TYPICAL,
   PRICE_WEIGHTED_STD= PRICE_WEIGHTED
  };

//--- Input Parameters ---
input int                       InpPeriodRSI    = 14;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferRSIH[];

//--- Global calculator object ---
CRSIHCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferRSIH, INDICATOR_DATA);
   ArraySetAsSeries(BufferRSIH, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CRSIHCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RSIH HA(%d)", InpPeriodRSI));
     }
   else
     {
      g_calculator = new CRSIHCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RSIH(%d)", InpPeriodRSI));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriodRSI))
     {
      Print("Failed to create or initialize RSIH Calculator object.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriodRSI + 1);
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

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferRSIH);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
