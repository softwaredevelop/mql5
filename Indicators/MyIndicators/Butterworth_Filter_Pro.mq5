//+------------------------------------------------------------------+
//|                                     Butterworth_Filter_Pro.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "John Ehlers' Higher-Order Butterworth Filter."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "Butterworth"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumPurple
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\Butterworth_Calculator.mqh>

enum ENUM_APPLIED_PRICE_HA_ALL
  {
   PRICE_HA_CLOSE    = -1, PRICE_HA_OPEN     = -2, PRICE_HA_HIGH     = -3, PRICE_HA_LOW      = -4,
   PRICE_HA_MEDIAN   = -5, PRICE_HA_TYPICAL  = -6, PRICE_HA_WEIGHTED = -7,
   PRICE_CLOSE_STD   = PRICE_CLOSE, PRICE_OPEN_STD    = PRICE_OPEN, PRICE_HIGH_STD    = PRICE_HIGH,
   PRICE_LOW_STD     = PRICE_LOW, PRICE_MEDIAN_STD  = PRICE_MEDIAN, PRICE_TYPICAL_STD = PRICE_TYPICAL,
   PRICE_WEIGHTED_STD= PRICE_WEIGHTED
  };

//--- Input Parameters ---
input int                       InpPeriod = 20;     // Critical Period for the filter
input ENUM_BUTTERWORTH_POLES    InpPoles  = POLES_TWO; // Number of poles (2 or 3)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferFilter[];

//--- Global calculator object ---
CButterworthCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferFilter,  INDICATOR_DATA);
   ArraySetAsSeries(BufferFilter,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CButterworthCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Butterworth HA(%d,%d)", InpPeriod, (int)InpPoles));
     }
   else
     {
      g_calculator = new CButterworthCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Butterworth(%d,%d)", InpPeriod, (int)InpPoles));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpPoles))
     {
      Print("Failed to initialize Butterworth Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod);
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
