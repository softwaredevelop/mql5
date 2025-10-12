//+------------------------------------------------------------------+
//|                                                 Supertrend_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "3.10" // Implemented gapped line drawing
#property description "Professional Supertrend with selectable candle and ATR source"
#property description "(Standard or Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 4 // 2 for Supertrend lines, 2 for colors
#property indicator_plots   2

//--- Plot 1: Supertrend line (Odd Segments)
#property indicator_label1  "Supertrend"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLimeGreen, clrTomato
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Supertrend line (Even Segments)
#property indicator_label2  "" // No label for the second part
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  clrLimeGreen, clrTomato
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

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
double    BufferSupertrend_Odd[];
double    BufferColor_Odd[];
double    BufferSupertrend_Even[];
double    BufferColor_Even[];

//--- Global calculator object (as a base class pointer) ---
CSupertrendCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferSupertrend_Odd,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferColor_Odd,       INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferSupertrend_Even, INDICATOR_DATA);
   SetIndexBuffer(3, BufferColor_Even,      INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(BufferSupertrend_Odd,  false);
   ArraySetAsSeries(BufferColor_Odd,       false);
   ArraySetAsSeries(BufferSupertrend_Even, false);
   ArraySetAsSeries(BufferColor_Even,      false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

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
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpAtrPeriod);

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
   g_calculator.Calculate(rates_total, open, high, low, close, BufferSupertrend_Odd, BufferColor_Odd, BufferSupertrend_Even, BufferColor_Even);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
