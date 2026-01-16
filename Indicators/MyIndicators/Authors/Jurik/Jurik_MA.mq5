//+------------------------------------------------------------------+
//|                                                 Jurik_MA_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.01" // Optimized for incremental calculation (O(1))
#property description "Professional Jurik Moving Average (JMA) with full Heikin Ashi support."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
#property indicator_label1  "JMA"

#include <MyIncludes\Jurik_Calculator.mqh>

//--- Input Parameters
input int                       InpLength = 14;              // JMA Length
input double                    InpPhase  = 0;               // JMA Phase (-100 to +100)
input ENUM_APPLIED_PRICE_HA_ALL InpPrice  = PRICE_CLOSE_STD; // Applied Price

//--- Indicator Buffers
double    BufferJMA[];

//--- Global Objects
CJurik_Calculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferJMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferJMA, false); // Standard chronological order

//--- Factory Logic for Calculator
// HA prices are usually negative in our enum, or specifically defined
   if(InpPrice <= PRICE_HA_CLOSE)
      g_calculator = new CJurik_Calculator_HA();
   else
      g_calculator = new CJurik_Calculator();

//--- Initialize Calculator
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpLength, InpPhase))
     {
      Print("Failed to initialize Jurik Calculator.");
      return(INIT_FAILED);
     }

//--- Visual Setup
   string price_str = "Std";
   if(InpPrice <= PRICE_HA_CLOSE)
      price_str = "HA";

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("JMA_Pro(%d, %.1f, %s)", InpLength, InpPhase, price_str));
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpLength);

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
   if(rates_total < InpLength)
      return(0);

//--- Run Calculator
// We pass the custom enum directly
   g_calculator.Calculate(rates_total, prev_calculated, InpPrice, open, high, low, close, BufferJMA);

   return(rates_total);
  }
//+------------------------------------------------------------------+
