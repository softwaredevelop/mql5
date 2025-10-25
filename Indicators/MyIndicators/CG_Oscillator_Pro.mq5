//+------------------------------------------------------------------+
//|                                            CG_Oscillator_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "John Ehlers' Center of Gravity (CG) Oscillator."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: CG Line
#property indicator_label1  "CG"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal Line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\CG_Oscillator_Calculator.mqh>

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   SOURCE_STANDARD,      // Use standard OHLC data
   SOURCE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input int               InpPeriod = 10;    // Observation Period
input ENUM_CANDLE_SOURCE InpSource = SOURCE_STANDARD;

//--- Indicator Buffers ---
double    BufferCG[];
double    BufferSignal[];

//--- Global calculator object ---
CCGOscillatorCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferCG,     INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferCG,     false);
   ArraySetAsSeries(BufferSignal, false);

   if(InpSource == SOURCE_HEIKIN_ASHI)
     {
      g_calculator = new CCGOscillatorCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CG HA(%d)", InpPeriod));
     }
   else
     {
      g_calculator = new CCGOscillatorCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CG(%d)", InpPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod))
     {
      Print("Failed to initialize CG Oscillator Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpPeriod + 1);
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
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// The calculator is hard-coded to use Median Price as per Ehlers' article
   g_calculator.Calculate(rates_total, PRICE_MEDIAN, open, high, low, close, BufferCG, BufferSignal);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
