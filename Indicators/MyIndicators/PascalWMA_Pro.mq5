//+------------------------------------------------------------------+
//|                                                PascalWMA_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.10" // Fixed Calculate parameters
#property description "Professional Pascal's Triangle WMA with selectable"
#property description "price source (Standard and Heikin Ashi)."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Include the calculator engine ---
#include <MyIncludes\PascalWMA_Calculator.mqh>

//--- Plot 1: Pascal WMA Line
#property indicator_label1  "Pascal WMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumPurple
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int                       InpPeriod      = 21;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferWMA[];

//--- Global calculator object ---
CPascalWMACalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferWMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferWMA, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CPascalWMACalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("PascalWMA HA(%d)", InpPeriod));
     }
   else
     {
      g_calculator = new CPascalWMACalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("PascalWMA(%d)", InpPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod))
     {
      Print("Failed to initialize Pascal WMA Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
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

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

// FIX: Added prev_calculated to the call
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferWMA);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
