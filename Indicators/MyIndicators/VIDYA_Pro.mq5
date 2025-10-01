//+------------------------------------------------------------------+
//|                                                    VIDYA_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00"
#property description "Professional Variable Index Dynamic Average (VIDYA) with selectable"
#property description "price source (Standard and Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label1  "VIDYA"

//--- Include the calculator engine ---
#include <MyIncludes\VIDYA_Calculator.mqh>

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
input int                       InpPeriodCMO    = 9;
input int                       InpPeriodEMA    = 12;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferVIDYA[];

//--- Global calculator object (as a base class pointer) ---
CVIDYACalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferVIDYA, INDICATOR_DATA);
   ArraySetAsSeries(BufferVIDYA, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CVIDYACalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("VIDYA HA(%d,%d)", InpPeriodCMO, InpPeriodEMA));
     }
   else
     {
      g_calculator = new CVIDYACalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("VIDYA(%d,%d)", InpPeriodCMO, InpPeriodEMA));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriodCMO, InpPeriodEMA))
     {
      Print("Failed to create or initialize VIDYA Calculator object.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriodCMO + InpPeriodEMA);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation function.                           |
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

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferVIDYA);

   return(rates_total);
  }
//+------------------------------------------------------------------+
