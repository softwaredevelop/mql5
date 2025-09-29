//+------------------------------------------------------------------+
//|                                                       CHO_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.01" // Corrected calculator call signature
#property description "Professional Chaikin Oscillator (CHO) with selectable MA type and"
#property description "candle source (Standard or Heikin Ashi) for the underlying ADL."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_label1  "CHO"
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

//--- Include the calculator engine ---
#include <MyIncludes\CHO_Calculator.mqh>

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input int                 InpFastPeriod   = 3;
input int                 InpSlowPeriod   = 10;
input ENUM_MA_METHOD      InpMaMethod     = MODE_EMA;
input ENUM_APPLIED_VOLUME InpVolumeType   = VOLUME_TICK;
input ENUM_CANDLE_SOURCE  InpCandleSource = CANDLE_STANDARD; // Candle source for ADL

//--- Indicator Buffers ---
double    BufferCHO[];

//--- Global calculator object (as a base class pointer) ---
CCHOCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the buffer and set as non-timeseries
   SetIndexBuffer(0, BufferCHO, INDICATOR_DATA);
   ArraySetAsSeries(BufferCHO, false);

//--- Dynamically create the appropriate calculator instance
   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CCHOCalculator_HA();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CHO HA(%d,%d)", InpFastPeriod, InpSlowPeriod));
         break;
      default: // CANDLE_STANDARD
         g_calculator = new CCHOCalculator_Std();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CHO(%d,%d)", InpFastPeriod, InpSlowPeriod));
         break;
     }

//--- Check if creation was successful and initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpFastPeriod, InpSlowPeriod, InpMaMethod, InpVolumeType))
     {
      Print("Failed to create or initialize CHO Calculator object.");
      return(INIT_FAILED);
     }

//--- Set indicator display properties
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_calculator.GetSlowPeriod() - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, 0);

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
//--- CORRECTED: Pass the 'open' array to the calculator
   g_calculator.Calculate(rates_total, open, high, low, close, tick_volume, volume, BufferCHO);

//--- Return rates_total for a full recalculation, ensuring stability
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
