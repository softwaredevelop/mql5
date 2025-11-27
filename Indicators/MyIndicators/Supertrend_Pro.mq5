//+------------------------------------------------------------------+
//|                                                 Supertrend_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "3.20" // Adapted to new ATR Calculator
#property description "Professional Supertrend with selectable candle and ATR source."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

//--- Plot 1: Supertrend line (Odd Segments)
#property indicator_label1  "Supertrend"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLimeGreen, clrTomato
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Supertrend line (Even Segments)
#property indicator_label2  ""
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  clrLimeGreen, clrTomato
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\Supertrend_Calculator.mqh>

//--- Input Parameters ---
input int                InpAtrPeriod    = 10;
input double             InpFactor       = 3.0;
input ENUM_CANDLE_SOURCE InpCandleSource = CANDLE_STANDARD;
input ENUM_CANDLE_SOURCE InpAtrSource    = CANDLE_STANDARD;

//--- Indicator Buffers ---
double    BufferSupertrend_Odd[], BufferColor_Odd[], BufferSupertrend_Even[], BufferColor_Even[];

//--- Global calculator object ---
CSupertrendCalculator *g_calculator;

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
      g_calculator = new CSupertrendCalculator_HA();
   else
      g_calculator = new CSupertrendCalculator();

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
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

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
