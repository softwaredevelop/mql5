//+------------------------------------------------------------------+
//|                                           FisherTransform_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "3.01" // Corrected calculator call signature
#property description "Professional Fisher Transform Oscillator with selectable"
#property description "candle source (Standard or Heikin Ashi)."

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_level1  1.5
#property indicator_level2  0.75
#property indicator_level3  0.0
#property indicator_level4 -0.75
#property indicator_level5 -1.5
#property indicator_levelstyle STYLE_DOT

//--- Buffers and Plots ---
#property indicator_buffers 2 // Fisher and Trigger
#property indicator_plots   2

//--- Plot 1: Fisher line
#property indicator_label1  "Fisher"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRoyalBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Trigger line
#property indicator_label2  "Trigger"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDarkOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Include the calculator engine ---
#include <MyIncludes\FisherTransform_Calculator.mqh>

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input int                InpLength       = 9;               // Length
input ENUM_CANDLE_SOURCE InpCandleSource = CANDLE_STANDARD; // Candle source

//--- Indicator Buffers ---
double    BufferFisher[];
double    BufferTrigger[];

//--- Global calculator object (as a base class pointer) ---
CFisherTransformCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the buffers and set as non-timeseries
   SetIndexBuffer(0, BufferFisher,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferTrigger, INDICATOR_DATA);
   ArraySetAsSeries(BufferFisher,  false);
   ArraySetAsSeries(BufferTrigger, false);

//--- Dynamically create the appropriate calculator instance
   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CFisherTransformCalculator_HA();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Fisher HA(%d)", InpLength));
         break;
      default: // CANDLE_STANDARD
         g_calculator = new CFisherTransformCalculator();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Fisher(%d)", InpLength));
         break;
     }

//--- Check if creation was successful and initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpLength))
     {
      Print("Failed to create or initialize Fisher Transform Calculator object.");
      return(INIT_FAILED);
     }

//--- Set indicator display properties
   IndicatorSetInteger(INDICATOR_DIGITS, 4);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpLength);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpLength + 1);

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
//--- CORRECTED: Pass all OHLC arrays for HA calculation
   g_calculator.Calculate(rates_total, open, high, low, close, BufferFisher, BufferTrigger);

//--- Return rates_total for a full recalculation, ensuring stability
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
