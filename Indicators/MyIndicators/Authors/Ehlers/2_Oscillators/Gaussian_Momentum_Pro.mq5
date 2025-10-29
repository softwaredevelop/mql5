//+------------------------------------------------------------------+
//|                                       Gaussian_Momentum_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Gaussian-smoothed Momentum Oscillator based on Ehlers' concepts."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "G-Momentum"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLimeGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_level1 0.0
#property indicator_levelstyle STYLE_SOLID
#property indicator_levelcolor clrGray

#include <MyIncludes\Gaussian_Filter_Calculator.mqh>

enum ENUM_CANDLE_SOURCE { SOURCE_STD, SOURCE_HA };

//--- Input Parameters ---
input int                InpPeriod       = 20;    // Cutoff Period for the filter
input ENUM_CANDLE_SOURCE InpCandleSource = SOURCE_STD;

//--- Indicator Buffers ---
double    BufferMomentum[];

//--- Global calculator object ---
CGaussianFilterCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMomentum,  INDICATOR_DATA);
   ArraySetAsSeries(BufferMomentum,  false);

   if(InpCandleSource == SOURCE_HA)
     {
      g_calculator = new CGaussianFilterCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("G-Mom HA(%d)", InpPeriod));
     }
   else
     {
      g_calculator = new CGaussianFilterCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("G-Mom(%d)", InpPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, SOURCE_MOMENTUM))
     {
      Print("Failed to initialize Gaussian Momentum Calculator.");
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

// price_type is not used in momentum mode, but we pass a default value
   g_calculator.Calculate(rates_total, PRICE_CLOSE, open, high, low, close, BufferMomentum);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
