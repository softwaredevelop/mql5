//+------------------------------------------------------------------+
//|                                                   Vortex_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Vortex Indicator (VI) with selectable"
#property description "candle source (Standard or Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_level1  1.0
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: +VI Line
#property indicator_label1  "+VI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: -VI Line
#property indicator_label2  "-VI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrTomato
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Include the calculator engine ---
#include <MyIncludes\Vortex_Calculator.mqh>

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input int                InpPeriod       = 21;
input ENUM_CANDLE_SOURCE InpCandleSource = CANDLE_STANDARD;

//--- Indicator Buffers ---
double    BufferVI_Plus[];
double    BufferVI_Minus[];

//--- Global calculator object (as a base class pointer) ---
CVortexCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferVI_Plus,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferVI_Minus, INDICATOR_DATA);
   ArraySetAsSeries(BufferVI_Plus,  false);
   ArraySetAsSeries(BufferVI_Minus, false);

   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CVortexCalculator_HA();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Vortex HA(%d)", InpPeriod));
         break;
      default: // CANDLE_STANDARD
         g_calculator = new CVortexCalculator();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Vortex(%d)", InpPeriod));
         break;
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod))
     {
      Print("Failed to create or initialize Vortex Calculator object.");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, 4);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpPeriod);

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
   g_calculator.Calculate(rates_total, open, high, low, close, BufferVI_Plus, BufferVI_Minus);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
