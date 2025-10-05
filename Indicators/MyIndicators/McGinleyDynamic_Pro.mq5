//+------------------------------------------------------------------+
//|                                        McGinleyDynamic_Pro.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "3.00"
#property description "Professional McGinley Dynamic Indicator with selectable"
#property description "price source (Standard and Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: McGinley Dynamic line
#property indicator_label1  "McGinley"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Include the calculator engine ---
#include <MyIncludes\McGinleyDynamic_Calculator.mqh>

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
input int                       InpLength       = 14;      // Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD; // Applied Price

//--- Indicator Buffers ---
double    BufferMcGinley[];

//--- Global calculator object (as a base class pointer) ---
CMcGinleyDynamicCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the buffer and set as non-timeseries
   SetIndexBuffer(0, BufferMcGinley, INDICATOR_DATA);
   ArraySetAsSeries(BufferMcGinley, false);

//--- Dynamically create the appropriate calculator instance
   if(InpSourcePrice <= PRICE_HA_CLOSE) // Heikin Ashi source selected
     {
      g_calculator = new CMcGinleyDynamicCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("McGinley HA(%d)", InpLength));
     }
   else // Standard price source selected
     {
      g_calculator = new CMcGinleyDynamicCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("McGinley(%d)", InpLength));
     }

//--- Check if creation was successful and initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpLength))
     {
      Print("Failed to create or initialize McGinley Dynamic Calculator object.");
      return(INIT_FAILED);
     }

//--- Set indicator display properties
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);

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

//--- Delegate the entire calculation to our calculator object
   g_calculator.Calculate(rates_total, open, high, low, close, price_type, BufferMcGinley);

//--- Return rates_total for a full recalculation, ensuring stability
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
