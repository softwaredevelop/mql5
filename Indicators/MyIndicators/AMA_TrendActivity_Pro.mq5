//+------------------------------------------------------------------+
//|                                        AMA_TrendActivity_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.10" // Optimized for incremental calculation
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

//--- Global calculator object (as a base class pointer) ---
CActivityCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the buffer and set as non-timeseries
   SetIndexBuffer(0, BufferActivity, INDICATOR_DATA);
   ArraySetAsSeries(BufferActivity, false);

//--- Dynamically create the appropriate calculator instance
   if(InpSourcePrice <= PRICE_HA_CLOSE) // Heikin Ashi source selected
     {
      g_calculator = new CActivityCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("AMA Activity HA(%d,%d,%d)", InpAmaPeriod, InpAtrPeriod, InpSmoothingPeriod));
     }
   else // Standard price source selected
     {
      g_calculator = new CActivityCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("AMA Activity(%d,%d,%d)", InpAmaPeriod, InpAtrPeriod, InpSmoothingPeriod));
     }

//--- Check if creation was successful and initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpAmaPeriod, InpFastEmaPeriod, InpSlowEmaPeriod, InpAtrPeriod, InpSmoothingPeriod))
     {
      Print("Failed to create or initialize Activity Calculator object.");
      return(INIT_FAILED);
     }

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
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Delegate calculation with prev_calculated optimization
   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, price_type, BufferActivity);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
