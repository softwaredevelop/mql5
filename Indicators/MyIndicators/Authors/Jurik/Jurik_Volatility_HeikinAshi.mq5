//+------------------------------------------------------------------+
//|                               Jurik_Volatility_HeikinAshi.mq5    |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Displays Jurik Volatility in a separate window, calculated from Heikin Ashi data."

#property indicator_separate_window
#property indicator_buffers 1 // Volatility
#property indicator_plots   1

#include <MyIncludes\Jurik_Calculators.mqh>

//--- Plot 1: Jurik Volatility
#property indicator_label1  "Volatility (HA)"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrOrangeRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Input Parameters ---
input int InpLength = 14; // Main Jurik Length

//--- Indicator Buffers ---
double BufferVolatility[];

//--- Global calculator object ---
CJurikMACalculator_HA *g_calculator; // Use the HA version of the calculator

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferVolatility, INDICATOR_DATA);
   ArraySetAsSeries(BufferVolatility, false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Jurik Volty HA(%d)", InpLength));

   g_calculator = new CJurikMACalculator_HA();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpLength, 0.0, 0))
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
      double dummy_jma[], dummy_upper[], dummy_lower[];
      g_calculator.Calculate(rates_total, open, high, low, close,
                             dummy_jma, dummy_upper, dummy_lower, BufferVolatility);
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
