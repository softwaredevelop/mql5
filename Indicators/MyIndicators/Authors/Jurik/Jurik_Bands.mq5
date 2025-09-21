//+------------------------------------------------------------------+
//|                                                Jurik_Bands.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.01"
#property description "Displays the Jurik Bands on the main chart."

#property indicator_chart_window
#property indicator_buffers 2 // Upper Band, Lower Band
#property indicator_plots   2

#include <MyIncludes\Jurik_Calculators.mqh>

//--- Plot 1: Upper Jurik Band
#property indicator_label1  "Upper Band"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_DOT
#property indicator_width1  1

//--- Plot 2: Lower Jurik Band
#property indicator_label2  "Lower Band"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Input Parameters ---
input int InpLength = 14; // Main Jurik Length

//--- Indicator Buffers ---
double BufferUpperBand[];
double BufferLowerBand[];

//--- Global calculator object ---
CJurikMACalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferUpperBand, INDICATOR_DATA);
   SetIndexBuffer(1, BufferLowerBand, INDICATOR_DATA);
   ArraySetAsSeries(BufferUpperBand, false);
   ArraySetAsSeries(BufferLowerBand, false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Jurik Bands(%d)", InpLength));

   g_calculator = new CJurikMACalculator();
//--- Corrected: Pass the neutral phase parameter (0.0) to the Init method
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpLength, 0.0, 0))
     {
      Print("Failed to initialize Jurik Calculator.");
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
      //--- Corrected: Pass dummy arrays for the unused JMA and Volatility outputs
      double dummy_jma[], dummy_volty[];
      g_calculator.Calculate(rates_total, open, high, low, close,
                             dummy_jma, BufferUpperBand, BufferLowerBand, dummy_volty);
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
