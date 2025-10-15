//+------------------------------------------------------------------+
//|                                                    Aroon_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2025, xxxxxxxx"
#property link        ""
#property version     "1.10" // Added fixed 0-100 scale
#property description "Aroon indicator with selectable candle source (Standard or Heikin Ashi)."

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_minimum 0   // <-- FIX: Force the bottom of the scale to 0
#property indicator_maximum 105 // <-- FIX: Force the top of the scale to 105
#property indicator_level1 30.0
#property indicator_level2 50.0
#property indicator_level3 70.0
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: Aroon Up
#property indicator_label1  "Aroon Up"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLimeGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Aroon Down
#property indicator_label2  "Aroon Down"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Include the calculator engine ---
#include <MyIncludes\Aroon_Calculator.mqh>

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input int                InpPeriodAroon  = 25;              // Period for Aroon calculation
input ENUM_CANDLE_SOURCE InpCandleSource = CANDLE_STANDARD; // Candle source

//--- Indicator Buffers ---
double    BufferAroonUp[];
double    BufferAroonDown[];

//--- Global calculator object (as a base class pointer) ---
CAroonCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the buffers
   SetIndexBuffer(0, BufferAroonUp,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferAroonDown, INDICATOR_DATA);

//--- Set all buffers as non-timeseries for stable calculation
   ArraySetAsSeries(BufferAroonUp,   false);
   ArraySetAsSeries(BufferAroonDown, false);

//--- Dynamically create the appropriate calculator instance
   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CAroonCalculator_HA();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Aroon Pro HA(%d)", InpPeriodAroon));
         break;
      default: // CANDLE_STANDARD
         g_calculator = new CAroonCalculator();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Aroon Pro(%d)", InpPeriodAroon));
         break;
     }

//--- Check if creation was successful and initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriodAroon))
     {
      Print("Failed to create or initialize Aroon Calculator object.");
      return(INIT_FAILED);
     }

//--- Set indicator properties
   int period = g_calculator.GetPeriod();
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, period - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, period - 1);

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

//--- Delegate the entire calculation to our calculator object
   g_calculator.Calculate(rates_total, high, low, BufferAroonUp, BufferAroonDown);

//--- Return rates_total for a full recalculation, ensuring stability
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
