//+------------------------------------------------------------------+
//|                                        Fisher_Transform_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Optimized for incremental calculation
#property description "John Ehlers' Fisher Transform for identifying sharp turning points."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_label1  "Fisher"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

#property indicator_level1 1.5
#property indicator_level2 -1.5
#property indicator_levelcolor clrGray
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\Fisher_Transform_Calculator.mqh>

enum ENUM_PRICE_SOURCE { SOURCE_STANDARD, SOURCE_HEIKIN_ASHI };

//--- Input Parameters ---
input int              InpPeriod = 10;    // Period for price normalization
input double           InpAlpha  = 0.33;  // Smoothing factor for normalized price
input ENUM_PRICE_SOURCE InpSource = SOURCE_STANDARD;

//--- Indicator Buffers ---
double    BufferFisher[];
double    BufferSignal[];

//--- Global calculator object ---
CFisherTransformCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferFisher, INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferFisher, false);
   ArraySetAsSeries(BufferSignal, false);

   if(InpSource == SOURCE_HEIKIN_ASHI)
     {
      g_calculator = new CFisherTransformCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Fisher HA(%d,%.2f)", InpPeriod, InpAlpha));
     }
   else
     {
      g_calculator = new CFisherTransformCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Fisher(%d,%.2f)", InpPeriod, InpAlpha));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpAlpha))
     {
      Print("Failed to initialize Fisher Transform Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpPeriod);
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

   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferFisher, BufferSignal);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
