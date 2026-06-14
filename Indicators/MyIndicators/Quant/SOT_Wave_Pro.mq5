//+------------------------------------------------------------------+
//|                                                   SOT_Wave_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Non-repainting state-machine, O(1) optimized
#property description "Wyckoff Shortening of the Thrust (SOT) Wave Detector"
#property description "Flags momentum exhaustion on the chart using non-repainting arrows."
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Bullish SOT (Demand Re-emergence / Green Arrow)
#property indicator_label1  "Bullish SOT"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLimeGreen
#property indicator_width1  2

//--- Plot 2: Bearish SOT (Supply Re-emergence / Red Arrow)
#property indicator_label2  "Bearish SOT"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrCrimson
#property indicator_width2  2

#include <MyIncludes\SOT_Wave_Calculator.mqh>

//--- Input Parameters
input int    InpATRPeriod = 14;   // ATR Sensitivity Period
input double InpMultiplier = 2.5;  // Wave Reversal Multiplier (ATR)

//--- Buffers
double ExtBullSOTBuffer[];
double ExtBearSOTBuffer[];

//--- Global Engine
CSOTWaveCalculator *g_calc;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, ExtBullSOTBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtBearSOTBuffer, INDICATOR_DATA);

   ArraySetAsSeries(ExtBullSOTBuffer, false);
   ArraySetAsSeries(ExtBearSOTBuffer, false);

// Configure MT5 Arrow codes (Up / Down standard arrows)
   PlotIndexSetInteger(0, PLOT_ARROW, 233); // Arrow pointing UP
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // Arrow pointing DOWN

   string short_name = StringFormat("SOT Wave Pro(%d, %.1f)", InpATRPeriod, InpMultiplier);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

   g_calc = new CSOTWaveCalculator();
   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpATRPeriod, InpMultiplier))
     {
      Print("Error: Failed to initialize SOT Calculator.");
      return INIT_FAILED;
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calc) == POINTER_DYNAMIC)
      delete g_calc;
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
// Force standard chronological indexing for Strategy Tester consistency
   ArraySetAsSeries(time, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);

   if(rates_total < InpATRPeriod + 10)
      return 0;

//--- Run the State Machine Engine
   g_calc.Calculate(rates_total, prev_calculated, time, high, low, close, ExtBullSOTBuffer, ExtBearSOTBuffer);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
