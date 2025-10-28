//+------------------------------------------------------------------+
//|                                       Laguerre_Momentum_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Laguerre-filtered Momentum Oscillator based on Ehlers' concepts."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "L-Momentum"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_level1 0.0
#property indicator_levelstyle STYLE_SOLID
#property indicator_levelcolor clrGray

#include <MyIncludes\Laguerre_Filter_Calculator.mqh>

enum ENUM_CANDLE_SOURCE { SOURCE_STD, SOURCE_HA };

//--- Input Parameters ---
input double             InpGamma        = 0.5;
input ENUM_CANDLE_SOURCE InpCandleSource = SOURCE_STD;

//--- Indicator Buffers ---
double    BufferMomentum[];
double    BufferDummy[]; // Dummy buffer for the unused FIR output

//--- Global calculator object ---
CLaguerreFilterCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMomentum,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferDummy,     INDICATOR_CALCULATIONS);
   ArraySetAsSeries(BufferMomentum,  false);
   ArraySetAsSeries(BufferDummy,     false);

   if(InpCandleSource == SOURCE_HA)
     {
      g_calculator = new CLaguerreFilterCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("L-Mom HA(%.2f)", InpGamma));
     }
   else
     {
      g_calculator = new CLaguerreFilterCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("L-Mom(%.2f)", InpGamma));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpGamma, SOURCE_MOMENTUM))
     {
      Print("Failed to initialize Laguerre Momentum Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   IndicatorSetInteger(INDICATOR_DIGITS, 4);

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

   g_calculator.Calculate(rates_total, PRICE_CLOSE, open, high, low, close, BufferMomentum, BufferDummy);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
