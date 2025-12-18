//+------------------------------------------------------------------+
//|                                        AMA_TrendActivity_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.00" // Refactored to use Composition Pattern
#property description "Measures the trend activity (slope) of an AMA line using Arctan normalization."
#property description "Selectable price source (Standard or Heikin Ashi) for both AMA and ATR calculations."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2
#property indicator_label1  "Activity"
#property indicator_minimum 0.0
#property indicator_maximum 0.5

//--- Include the calculator engine ---
#include <MyIncludes\AMA_TrendActivity_Calculator.mqh>

//--- Input Parameters ---
input group                     "AMA Settings"
input int                       InpAmaPeriod     = 10;
input int                       InpFastEmaPeriod = 2;
input int                       InpSlowEmaPeriod = 30;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice   = PRICE_CLOSE_STD;

input group                     "Activity Calculation Settings"
input int                       InpAtrPeriod     = 14;
input int                       InpSmoothingPeriod = 5;

//--- Indicator Buffers ---
double    BufferActivity[];

//--- Global calculator object ---
CActivityCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the buffer and set as non-timeseries
   SetIndexBuffer(0, BufferActivity, INDICATOR_DATA);
   ArraySetAsSeries(BufferActivity, false);

//--- Create the calculator instance
   g_calculator = new CActivityCalculator();

//--- Determine if Heikin Ashi is needed
   bool use_ha = (InpSourcePrice <= PRICE_HA_CLOSE);

//--- Initialize the calculator
//--- Note: We pass 'use_ha' here, and the calculator handles the sub-engines internally.
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpAmaPeriod, InpFastEmaPeriod, InpSlowEmaPeriod, InpAtrPeriod, InpSmoothingPeriod, use_ha))
     {
      Print("Failed to create or initialize Activity Calculator object.");
      return(INIT_FAILED);
     }

//--- Set Short Name
   string type = use_ha ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("AMA Activity%s(%d,%d,%d)", type, InpAmaPeriod, InpAtrPeriod, InpSmoothingPeriod));

//--- Set indicator display properties
   int draw_begin = InpAmaPeriod + InpAtrPeriod + InpSmoothingPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 4);
   IndicatorSetDouble(INDICATOR_MINIMUM, 0.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 0.5);

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
//| Custom indicator calculation function.                           |
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
//--- Ensure the calculator object is valid
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

//--- Convert our custom enum to the standard ENUM_APPLIED_PRICE
   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Delegate the calculation with incremental optimization
   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, price_type, BufferActivity);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
