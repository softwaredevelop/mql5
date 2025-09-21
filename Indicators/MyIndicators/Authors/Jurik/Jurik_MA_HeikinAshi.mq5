//+------------------------------------------------------------------+
//|                                       Jurik_MA_HeikinAshi.mq5    |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Jurik Moving Average (JMA) indicator on Heikin Ashi data."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

#include <MyIncludes\Jurik_Calculators.mqh>

//--- Plot 1: JMA Line
#property indicator_label1  "JMA (HA)"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int    InpLength = 14;
input double InpPhase  = 0;

//--- Indicator Buffers ---
double    BufferJMA[];

//--- Global calculator object ---
CJurikMACalculator_HA *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferJMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferJMA, false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpLength);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("JMA_HA(%d, %.1f)", InpLength, InpPhase));

   g_calculator = new CJurikMACalculator_HA();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpLength, InpPhase, 0))
     {
      Print("Failed to initialize Jurik HA Calculator.");
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
   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      double dummy_upper[], dummy_lower[], dummy_volty[];
      g_calculator.Calculate(rates_total, open, high, low, close,
                             BufferJMA, dummy_upper, dummy_lower, dummy_volty);
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
