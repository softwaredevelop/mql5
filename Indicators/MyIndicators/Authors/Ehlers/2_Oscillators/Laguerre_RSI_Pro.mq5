//+------------------------------------------------------------------+
//|                                             Laguerre_RSI_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.21" // Changed to Display Mode enum
#property description "John Ehlers' Laguerre RSI with an optional signal line."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Laguerre RSI Line
#property indicator_label1  "Laguerre RSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal Line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLightCoral
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Scale and Level Properties ---
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 10.0
#property indicator_level2 20.0
#property indicator_level3 50.0
#property indicator_level4 80.0
#property indicator_level5 90.0
#property indicator_levelcolor clrGray
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\Laguerre_RSI_Calculator.mqh>

//--- NEW: Enum for Display Mode ---
enum ENUM_LRSI_DISPLAY_MODE
  {
   DISPLAY_LRSI_ONLY,
   DISPLAY_LRSI_AND_SIGNAL
  };

//--- Input Parameters ---
input group "Laguerre RSI Settings"
input double                    InpGamma        = 0.5;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

input group "Signal Line Settings"
input ENUM_LRSI_DISPLAY_MODE InpDisplayMode  = DISPLAY_LRSI_AND_SIGNAL;
input int                    InpSignalPeriod = 3;
input ENUM_MA_TYPE           InpSignalMAType = EMA;

//--- Indicator Buffers ---
double    BufferLRSI[], BufferSignal[];

//--- Global calculator object ---
CLaguerreRSICalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferLRSI,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferLRSI,   false);
   ArraySetAsSeries(BufferSignal, false);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CLaguerreRSICalculator_HA();
   else
      g_calculator = new CLaguerreRSICalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpGamma, InpSignalPeriod, InpSignalMAType))
     {
      Print("Failed to create or initialize Laguerre RSI Calculator object.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Laguerre RSI%s(%.2f)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpGamma));
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 2 + InpSignalPeriod - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;
   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferLRSI, BufferSignal);

//--- UPDATED: Use the new display mode logic ---
   if(InpDisplayMode == DISPLAY_LRSI_ONLY)
     {
      for(int i=0; i<rates_total; i++)
         BufferSignal[i] = EMPTY_VALUE;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
