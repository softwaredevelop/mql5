//+------------------------------------------------------------------+
//|                                          Holt_MA_HeikinAshi.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Holt's Linear Trend Method on Heikin Ashi data."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

#include <MyIncludes\Holt_Calculator.mqh>

//--- Plot 1: Holt MA Forecast Line
#property indicator_label1  "Holt MA (HA)"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int    InpPeriod = 20;
input double InpAlpha  = 0.1;
input double InpBeta   = 0.05;

//--- Indicator Buffers ---
double    BufferHoltMA[];

//--- Global calculator object ---
CHoltMACalculator_HA *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferHoltMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferHoltMA, false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Holt MA HA(%d, %.2f, %.2f)", InpPeriod, InpAlpha, InpBeta));

   g_calculator = new CHoltMACalculator_HA();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpAlpha, InpBeta))
     {
      Print("Failed to initialize Holt MA HA Calculator.");
      return(INIT_FAILED);
     }
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
      double dummy_trend[], dummy_level[];
      g_calculator.Calculate(rates_total, PRICE_CLOSE, open, high, low, close, BufferHoltMA, dummy_trend, dummy_level);
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
