//+------------------------------------------------------------------+
//|                                       UltimateOscillator_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.00" // Refactored to use MovingAverage_Engine
#property description "Professional Ultimate Oscillator with an optional signal line and"
#property description "selectable candle source (Standard or Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 2 // UO and Signal Line
#property indicator_plots   2
#property indicator_maximum 100.0
#property indicator_minimum 0.0
#property indicator_level1  30.0
#property indicator_level2  50.0
#property indicator_level3  70.0
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: UO Line
#property indicator_label1  "UO"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal Line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Include the calculator engine ---
#include <MyIncludes\UltimateOscillator_Calculator.mqh>

//--- Enum for Display Mode ---
enum ENUM_DISPLAY_MODE
  {
   DISPLAY_UO_ONLY,       // Display only the UO line
   DISPLAY_UO_AND_SIGNAL  // Display UO and its signal line
  };

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input group              "Oscillator Settings"
input int                InpPeriod1      = 7;
input int                InpPeriod2      = 14;
input int                InpPeriod3      = 28;
input ENUM_CANDLE_SOURCE InpCandleSource = CANDLE_STANDARD;
input group              "Signal Line Settings"
input ENUM_DISPLAY_MODE  InpDisplayMode  = DISPLAY_UO_AND_SIGNAL;
input int                InpSignalPeriod = 9;
// UPDATED: Use ENUM_MA_TYPE
input ENUM_MA_TYPE       InpSignalMAType = SMA;

//--- Indicator Buffers ---
double    BufferUO[];
double    BufferSignal[];

//--- Global calculator object ---
CUltimateOscillatorCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferUO,     INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferUO,     false);
   ArraySetAsSeries(BufferSignal, false);

   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CUltimateOscillatorCalculator_HA();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("UO HA(%d,%d,%d)", InpPeriod1, InpPeriod2, InpPeriod3));
         break;
      default:
         g_calculator = new CUltimateOscillatorCalculator();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("UO(%d,%d,%d)", InpPeriod1, InpPeriod2, InpPeriod3));
         break;
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod1, InpPeriod2, InpPeriod3, InpSignalPeriod, InpSignalMAType))
     {
      Print("Failed to create or initialize Ultimate Oscillator Calculator object.");
      return(INIT_FAILED);
     }

   int uo_draw_begin = MathMax(InpPeriod1, MathMax(InpPeriod2, InpPeriod3));
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, uo_draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, uo_draw_begin + InpSignalPeriod - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

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
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferUO, BufferSignal);

   if(InpDisplayMode == DISPLAY_UO_ONLY)
     {
      int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      for(int i = start; i < rates_total; i++)
         BufferSignal[i] = EMPTY_VALUE;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
