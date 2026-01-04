//+------------------------------------------------------------------+
//|                                     Inverse_Fisher_RSI_Pro.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Optimized for incremental calculation
#property description "John Ehlers' Inverse Fisher Transform of RSI for clear buy/sell signals."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "IFish RSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrTeal
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_minimum -1.1
#property indicator_maximum 1.1
#property indicator_level1 0.5
#property indicator_level2 -0.5
#property indicator_levelcolor clrGray
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\Inverse_Fisher_RSI_Calculator.mqh>

enum ENUM_PRICE_SOURCE { SOURCE_STANDARD, SOURCE_HEIKIN_ASHI };

//--- Input Parameters ---
input int              InpRSI_Period = 5;     // RSI Period
input int              InpWMA_Period = 9;     // WMA Smoothing Period
input ENUM_PRICE_SOURCE InpSource = SOURCE_STANDARD;

//--- Indicator Buffers ---
double    BufferIFish[];

//--- Global calculator object ---
CInverseFisherRSICalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferIFish, INDICATOR_DATA);
   ArraySetAsSeries(BufferIFish, false);

   if(InpSource == SOURCE_HEIKIN_ASHI)
     {
      g_calculator = new CInverseFisherRSICalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("IFish RSI HA(%d,%d)", InpRSI_Period, InpWMA_Period));
     }
   else
     {
      g_calculator = new CInverseFisherRSICalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("IFish RSI(%d,%d)", InpRSI_Period, InpWMA_Period));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpRSI_Period, InpWMA_Period))
     {
      Print("Failed to initialize Inverse Fisher RSI Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpRSI_Period + InpWMA_Period);
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
int OnCalculate(const int rates_total, const int prev_calculated, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// We pass PRICE_CLOSE as a dummy because RSI engine uses Close by default (or HA Close)
// The calculator handles HA switching internally based on object type
   g_calculator.Calculate(rates_total, prev_calculated, PRICE_CLOSE, open, high, low, close, BufferIFish);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
