//+------------------------------------------------------------------+
//|                                                       AMA_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00"
#property description "Professional Adaptive Moving Average (AMA) by Perry Kaufman with"
#property description "selectable price source (Standard and Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label1  "AMA"

//--- Include the calculator engine ---
#include <MyIncludes\AMA_Calculator.mqh>

//--- Input Parameters ---
input int                       InpAmaPeriod     = 10;      // AMA Efficiency Ratio Period
input int                       InpFastEmaPeriod = 2;       // Fast EMA Period for scaling
input int                       InpSlowEmaPeriod = 30;      // Slow EMA Period for scaling
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice   = PRICE_CLOSE_STD; // Applied Price

//--- Indicator Buffers ---
double    BufferAMA[];

//--- Global calculator object (as a base class pointer) ---
CAMACalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the buffer and set as non-timeseries
   SetIndexBuffer(0, BufferAMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferAMA, false);

//--- Dynamically create the appropriate calculator instance
   if(InpSourcePrice <= PRICE_HA_CLOSE) // Heikin Ashi source selected
     {
      g_calculator = new CAMACalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("AMA HA(%d,%d,%d)", InpAmaPeriod, InpFastEmaPeriod, InpSlowEmaPeriod));
     }
   else // Standard price source selected
     {
      g_calculator = new CAMACalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("AMA(%d,%d,%d)", InpAmaPeriod, InpFastEmaPeriod, InpSlowEmaPeriod));
     }

//--- Check if creation was successful and initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpAmaPeriod, InpFastEmaPeriod, InpSlowEmaPeriod))
     {
      Print("Failed to create or initialize AMA Calculator object.");
      return(INIT_FAILED);
     }

//--- Set indicator display properties
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_calculator.GetPeriod());
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

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
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice); // Convert e.g. -1 to 1 (PRICE_CLOSE)
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Delegate the entire calculation to our calculator object
   g_calculator.Calculate(rates_total, open, high, low, close, price_type, BufferAMA);

//--- Return rates_total for a full recalculation, ensuring stability
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
