//+------------------------------------------------------------------+
//|                                     MAMA_FAMA_HeikinAshi.mq5     |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.01"
#property description "MESA Adaptive Moving Average (MAMA) and FAMA on Heikin Ashi data."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#include <MyIncludes\MESA_Calculator.mqh>

//--- Plot 1: MAMA Line
#property indicator_label1  "MAMA (HA)"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: FAMA Line
#property indicator_label2  "FAMA (HA)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGreen
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Input Parameters ---
input double InpFastLimit   = 0.5;
input double InpSlowLimit   = 0.05;

//--- Indicator Buffers ---
double    BufferMAMA[];
double    BufferFAMA[];

//--- Global calculator object ---
CMESACalculator_HA *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMAMA, INDICATOR_DATA);
   SetIndexBuffer(1, BufferFAMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferMAMA, false);
   ArraySetAsSeries(BufferFAMA, false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 10);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 10);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MAMA/FAMA HA(%.2f, %.2f)", InpFastLimit, InpSlowLimit));

   g_calculator = new CMESACalculator_HA();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpFastLimit, InpSlowLimit))
     {
      Print("Failed to initialize MESA HA Calculator.");
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
      //--- The HA calculator needs the original OHLC for conversion.
      //--- The price_type parameter is ignored by the HA calculator.
      g_calculator.Calculate(rates_total, PRICE_CLOSE, open, high, low, close, BufferMAMA, BufferFAMA);
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
