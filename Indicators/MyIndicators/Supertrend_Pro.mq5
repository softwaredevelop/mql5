//+------------------------------------------------------------------+
//|                                                 Supertrend_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "3.01" // Corrected enum definition
#property description "Professional Supertrend with selectable candle and ATR source"
#property description "(Standard or Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 2 // Supertrend line and color
#property indicator_plots   1

//--- Plot 1: Supertrend line
#property indicator_label1  "Supertrend"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLimeGreen, clrTomato
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Include the calculator engine ---
#include <MyIncludes\Supertrend_Calculator.mqh>

//--- Enum for Candle Source ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input int               InpAtrPeriod    = 10;
input double            InpFactor       = 3.0;
input ENUM_CANDLE_SOURCE InpCandleSource = CANDLE_STANDARD;
input ENUM_ATR_SOURCE   InpAtrSource    = ATR_SOURCE_STANDARD;

//--- Indicator Buffers ---
double    BufferSupertrend[];
double    BufferColor[];

//--- Global calculator object (as a base class pointer) ---
CSupertrendCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferSupertrend, INDICATOR_DATA);
   SetIndexBuffer(1, BufferColor,      INDICATOR_COLOR_INDEX);
   ArraySetAsSeries(BufferSupertrend, false);
   ArraySetAsSeries(BufferColor,      false);

   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
     {
      g_calculator = new CSupertrendCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Supertrend HA(%d,%.1f)", InpAtrPeriod, InpFactor));
     }
   else
     {
      g_calculator = new CSupertrendCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Supertrend(%d,%.1f)", InpAtrPeriod, InpFactor));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpAtrPeriod, InpFactor, InpAtrSource))
     {
      Print("Failed to create or initialize Supertrend Calculator object.");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpAtrPeriod);

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
   g_calculator.Calculate(rates_total, open, high, low, close, BufferSupertrend, BufferColor);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
