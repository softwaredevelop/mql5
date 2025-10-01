//+------------------------------------------------------------------+
//|                                       UltimateOscillator_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00"
#property description "Professional Ultimate Oscillator with selectable"
#property description "candle source (Standard or Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_maximum 100.0
#property indicator_minimum 0.0
#property indicator_level1  30.0
#property indicator_level2  50.0
#property indicator_level3  70.0
#property indicator_levelstyle STYLE_DOT

//--- Include the calculator engine ---
#include <MyIncludes\UltimateOscillator_Calculator.mqh>

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input int                InpPeriod1      = 7;  // Fast Period
input int                InpPeriod2      = 14; // Middle Period
input int                InpPeriod3      = 28; // Slow Period
input ENUM_CANDLE_SOURCE InpCandleSource = CANDLE_STANDARD;

//--- Indicator Buffers ---
double    BufferUO[];

//--- Global calculator object (as a base class pointer) ---
CUltimateOscillatorCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferUO, INDICATOR_DATA);
   ArraySetAsSeries(BufferUO, false);

   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CUltimateOscillatorCalculator_HA();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("UO HA(%d,%d,%d)", InpPeriod1, InpPeriod2, InpPeriod3));
         break;
      default: // CANDLE_STANDARD
         g_calculator = new CUltimateOscillatorCalculator();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("UO(%d,%d,%d)", InpPeriod1, InpPeriod2, InpPeriod3));
         break;
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod1, InpPeriod2, InpPeriod3))
     {
      Print("Failed to create or initialize Ultimate Oscillator Calculator object.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, MathMax(InpPeriod1, MathMax(InpPeriod2, InpPeriod3)));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

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
   g_calculator.Calculate(rates_total, open, high, low, close, BufferUO);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
