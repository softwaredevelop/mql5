//+------------------------------------------------------------------+
//|                                         WeisWave_Duration_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Upgraded with 4-color integrated SOT-duration highlighting
#property description "Professional Weis Wave Duration (Wyckoff Wave Time / Bar Count)."
#property description "Tracks cumulative bar duration and highlights SOT waves in Orange/Fuchsia."
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Plot: Color Histogram (Upgraded with SOT colors)
#property indicator_label1  "Wave Duration"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Palette:
// 0: DodgerBlue (Normal Up Duration)
// 1: Crimson    (Normal Down Duration)
// 2: Orange     (Exhausted Up Duration / Bearish SOT)
// 3: Magenta    (Exhausted Down Duration / Bullish SOT)
#property indicator_color1  clrDodgerBlue, clrCrimson, clrOrange, clrFuchsia
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

#include <MyIncludes\WeisWave_Duration_Calculator.mqh>

//--- Input Parameters
input int    InpATRPeriod  = 14;   // ATR Sensitivity Period
input double InpMultiplier = 2.5;  // Wave Reversal Multiplier (ATR)
input bool   InpShowSOT    = true; // Highlight SOT (Momentum Exhaustion) waves?

//--- Buffers
double ExtWaveDurBuffer[];
double ExtColorsBuffer[];

//--- Global Engine
CWeisWaveDurationCalculator *g_calc;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, ExtWaveDurBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtColorsBuffer, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(ExtWaveDurBuffer, false);
   ArraySetAsSeries(ExtColorsBuffer, false);

   string short_name = StringFormat("Weis Wave Duration Pro(%d, %.1f, SOT:%s)",
                                    InpATRPeriod, InpMultiplier, (InpShowSOT ? "ON" : "OFF"));
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, 0);

   g_calc = new CWeisWaveDurationCalculator();
   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpATRPeriod, InpMultiplier))
     {
      Print("Error: Failed to initialize WeisWave Duration Calculator.");
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
   if(rates_total < InpATRPeriod + 10)
      return 0;

//--- Force standard chronological indexing for Strategy Tester consistency
   ArraySetAsSeries(time, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);

//--- Run the State Machine Engine with SOT highlighting toggle
   g_calc.Calculate(rates_total, prev_calculated, high, low, close, ExtWaveDurBuffer, ExtColorsBuffer, InpShowSOT);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
