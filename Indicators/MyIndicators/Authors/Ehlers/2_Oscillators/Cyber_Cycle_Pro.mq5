//+------------------------------------------------------------------+
//|                                              Cyber_Cycle_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.00" // Optimized for incremental calculation
#property description "John Ehlers' Cyber Cycle indicator for identifying market cycles."
#property description "Features O(1) calculation and full Heikin Ashi support."

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
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_level1 0.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\Cyber_Cycle_Calculator.mqh>

//--- Input Parameters ---
input double                    InpAlpha       = 0.07;            // Smoothing factor
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_MEDIAN_STD; // Price Source (Default: Median)

//--- Indicator Buffers ---
double    BufferCycle[];
double    BufferSignal[];

//--- Global calculator object ---
CCyberCycleCalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferCycle,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferCycle,  false);
   ArraySetAsSeries(BufferSignal, false);

//--- Factory Logic
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CCyberCycleCalculator_HA();
   else
      g_calculator = new CCyberCycleCalculator();

//--- Initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpAlpha))
     {
      Print("Failed to initialize Cyber Cycle Calculator.");
      return(INIT_FAILED);
     }

//--- Shortname
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Cyber Cycle%s(%.2f)", type, InpAlpha));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 7);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 9);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
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
   if(rates_total < 7)
      return(0);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          BufferCycle, BufferSignal);

   return(rates_total);
  }
//+------------------------------------------------------------------+
