//+------------------------------------------------------------------+
//|                                              FibonacciWMA_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.00"
#property description "Professional Fibonacci Weighted Moving Average with selectable"
#property description "price source (Standard and Heikin Ashi)."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Include the calculator engine ---
#include <MyIncludes\Fibonacci_WMA_Calculator.mqh>

//--- Plot 1: Fibonacci WMA Line
#property indicator_label1  "Fibonacci WMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Custom Enum for Price Source, including Heikin Ashi ---
enum ENUM_APPLIED_PRICE_HA_ALL
  {
//--- Heikin Ashi Prices (negative values for easy identification)
   PRICE_HA_CLOSE    = -1,
   PRICE_HA_OPEN     = -2,
   PRICE_HA_HIGH     = -3,
   PRICE_HA_LOW      = -4,
   PRICE_HA_MEDIAN   = -5,
   PRICE_HA_TYPICAL  = -6,
   PRICE_HA_WEIGHTED = -7,
//--- Standard Prices (using built-in ENUM_APPLIED_PRICE values)
   PRICE_CLOSE_STD   = PRICE_CLOSE,
   PRICE_OPEN_STD    = PRICE_OPEN,
   PRICE_HIGH_STD    = PRICE_HIGH,
   PRICE_LOW_STD     = PRICE_LOW,
   PRICE_MEDIAN_STD  = PRICE_MEDIAN,
   PRICE_TYPICAL_STD = PRICE_TYPICAL,
   PRICE_WEIGHTED_STD= PRICE_WEIGHTED
  };

//--- Input Parameters ---
input int                       InpPeriod      = 21;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferWMA[];

//--- Global calculator object (as a base class pointer) ---
CFibonacciWMACalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the buffer and set as non-timeseries
   SetIndexBuffer(0, BufferWMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferWMA, false);

//--- Dynamically create the appropriate calculator instance
   if(InpSourcePrice <= PRICE_HA_CLOSE) // Heikin Ashi source selected
     {
      g_calculator = new CFibonacciWMACalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("FibWMA HA(%d)", InpPeriod));
     }
   else // Standard price source selected
     {
      g_calculator = new CFibonacciWMACalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("FibWMA(%d)", InpPeriod));
     }

//--- Check if creation was successful and initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod))
     {
      Print("Failed to initialize Fibonacci WMA Calculator.");
      return(INIT_FAILED);
     }

//--- Set indicator display properties
   int actual_period = InpPeriod > 40 ? 40 : InpPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, actual_period - 1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Free the calculator object to prevent memory leaks
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function.                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
//--- Ensure the calculator object is valid
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

//--- Convert our custom enum to the standard ENUM_APPLIED_PRICE
   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Delegate the entire calculation to our calculator object
   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferWMA);

//--- Return rates_total for a full recalculation, ensuring stability
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
