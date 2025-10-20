//+------------------------------------------------------------------+
//|                                              Cyber_Cycle_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "John Ehlers' Cyber Cycle indicator for identifying market cycles."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Cyber Cycle Line
#property indicator_label1  "Cycle"
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

#property indicator_level1 0.0
#property indicator_levelstyle STYLE_SOLID
#property indicator_levelcolor clrGray

#include <MyIncludes\Cyber_Cycle_Calculator.mqh>

enum ENUM_PRICE_SOURCE { SOURCE_STANDARD, SOURCE_HEIKIN_ASHI };

//--- Input Parameters ---
input double           InpAlpha  = 0.07;  // Smoothing factor
input ENUM_PRICE_SOURCE InpSource = SOURCE_STANDARD;

//--- Indicator Buffers ---
double    BufferCycle[];
double    BufferSignal[];

//--- Global calculator object ---
CCyberCycleCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferCycle,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferCycle,  false);
   ArraySetAsSeries(BufferSignal, false);

   if(InpSource == SOURCE_HEIKIN_ASHI)
     {
      g_calculator = new CCyberCycleCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Cyber Cycle HA(%.2f)", InpAlpha));
     }
   else
     {
      g_calculator = new CCyberCycleCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Cyber Cycle(%.2f)", InpAlpha));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpAlpha))
     {
      Print("Failed to initialize Cyber Cycle Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 7);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 9);
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
   g_calculator.Calculate(rates_total, open, high, low, close, BufferCycle, BufferSignal);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
