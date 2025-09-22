//+------------------------------------------------------------------+
//|                                          Sine_WMA_HeikinAshi.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Sine Weighted Moving Average on Heikin Ashi data."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

#include <MyIncludes\Sine_WMA_Calculator.mqh>

//--- Plot 1: Sine WMA Line
#property indicator_label1  "Sine WMA (HA)"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrAqua
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int InpPeriod = 21;

//--- Indicator Buffers ---
double    BufferWMA[];

//--- Global calculator object ---
CSineWMACalculator_HA *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferWMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferWMA, false);

   g_calculator = new CSineWMACalculator_HA();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod))
     {
      Print("Failed to initialize Sine WMA HA Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("SineWMA_HA(%d)", InpPeriod));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function.                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      //--- The price_type parameter is ignored by the HA calculator, so we can pass a default
      g_calculator.Calculate(rates_total, PRICE_CLOSE, open, high, low, close, BufferWMA);
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
