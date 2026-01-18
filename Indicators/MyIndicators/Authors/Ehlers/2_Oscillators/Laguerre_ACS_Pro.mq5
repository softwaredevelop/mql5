//+------------------------------------------------------------------+
//|                                             Laguerre_ACS_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Laguerre Adaptive Cyber Cycle (ACS). Combines Adaptive Laguerre"
#property description "filtering with the Cyber Cycle for superior cycle detection."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Cycle Line
#property indicator_label1  "ACS Cycle"
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

#include <MyIncludes\Laguerre_ACS_Calculator.mqh>

//--- Input Parameters
input double                    InpAlpha        = 0.07;            // Cyber Cycle Alpha
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_MEDIAN_STD; // Price Source

//--- Buffers
double    BufferCycle[];
double    BufferSignal[];

//--- Global Object
CLaguerreACSCalculator *g_calculator;

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
      g_calculator = new CLaguerreACSCalculator_HA();
   else
      g_calculator = new CLaguerreACSCalculator();

//--- Initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpAlpha))
     {
      Print("Failed to initialize Laguerre ACS Calculator.");
      return(INIT_FAILED);
     }

//--- Shortname
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Laguerre ACS%s(%.2f)", type, InpAlpha));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 10);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 11);
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
   if(rates_total < 10)
      return(0);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          BufferCycle, BufferSignal);

   return(rates_total);
  }
//+------------------------------------------------------------------+
