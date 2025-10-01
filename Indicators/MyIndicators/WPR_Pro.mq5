//+------------------------------------------------------------------+
//|                                                       WPR_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "3.00"
#property description "Professional Williams' Percent Range (WPR) with optional signal line"
#property description "and selectable candle source (Standard or Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 2 // WPR and Signal Line
#property indicator_plots   2
#property indicator_level1 -20.0
#property indicator_level2 -80.0
#property indicator_levelstyle STYLE_DOT
#property indicator_maximum 0.0
#property indicator_minimum -100.0

//--- Plot 1: WPR line
#property indicator_label1  "WPR"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Include the calculator engine ---
#include <MyIncludes\WPR_Calculator.mqh>

//--- Enum for Display Mode ---
enum ENUM_DISPLAY_MODE
  {
   DISPLAY_WPR_ONLY,      // Display only the WPR line
   DISPLAY_WPR_AND_SIGNAL // Display WPR and its signal line
  };

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input int                InpWPRPeriod    = 14;
input ENUM_CANDLE_SOURCE InpCandleSource = CANDLE_STANDARD;
input group              "Signal Line Settings"
input ENUM_DISPLAY_MODE  InpDisplayMode  = DISPLAY_WPR_AND_SIGNAL;
input int                InpSignalPeriod = 3;
input ENUM_MA_METHOD     InpSignalMAType = MODE_SMA;

//--- Indicator Buffers ---
double    BufferWPR[];
double    BufferSignal[];

//--- Global calculator object (as a base class pointer) ---
CWPRCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferWPR,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferWPR,    false);
   ArraySetAsSeries(BufferSignal, false);

   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
     {
      g_calculator = new CWPRCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("WPR HA(%d,%d)", InpWPRPeriod, InpSignalPeriod));
     }
   else
     {
      g_calculator = new CWPRCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("WPR(%d,%d)", InpWPRPeriod, InpSignalPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpWPRPeriod, InpSignalPeriod, InpSignalMAType))
     {
      Print("Failed to create or initialize WPR Calculator object.");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpWPRPeriod - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpWPRPeriod + InpSignalPeriod - 2);

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

   g_calculator.Calculate(rates_total, open, high, low, close, BufferWPR, BufferSignal);

   if(InpDisplayMode == DISPLAY_WPR_ONLY)
     {
      for(int i=0; i<rates_total; i++)
         BufferSignal[i] = EMPTY_VALUE;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
