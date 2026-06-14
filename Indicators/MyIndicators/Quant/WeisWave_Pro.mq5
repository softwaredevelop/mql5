//+------------------------------------------------------------------+
//|                                                   WeisWave_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Upgraded with 4-color integrated SOT highlighting
#property description "Professional Weis Wave Volume (Wyckoff Supply vs Demand)."
#property description "Tracks cumulative volume and highlights SOT waves in Orange/Fuchsia."
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Plot: Color Histogram (Upgraded with SOT colors)
#property indicator_label1  "Wave Volume"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Palette:
// 0: DodgerBlue (Normal Demand / Up)
// 1: Crimson    (Normal Supply / Down)
// 2: Orange     (Exhausted Demand / Bearish SOT)
// 3: Magenta    (Exhausted Supply / Bullish SOT)
#property indicator_color1  clrDodgerBlue, clrCrimson, clrOrange, clrFuchsia
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

#include <MyIncludes\WeisWave_Calculator.mqh>

//--- Input Parameters
input int    InpATRPeriod = 14;   // ATR Sensitivity Period
input double InpMultiplier = 2.5;  // Wave Reversal Multiplier (ATR)
input bool   InpShowSOT   = true; // Highlight SOT (Momentum Exhaustion) waves?

//--- Buffers
double ExtWaveVolBuffer[];
double ExtColorsBuffer[];

//--- Global Engine
CWeisWaveCalculator *g_calc;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, ExtWaveVolBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtColorsBuffer, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(ExtWaveVolBuffer, false);
   ArraySetAsSeries(ExtColorsBuffer, false);

   string short_name = StringFormat("Weis Wave Volume Pro(%d, %.1f, SOT:%s)",
                                    InpATRPeriod, InpMultiplier, (InpShowSOT ? "ON" : "OFF"));
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, 0);

   g_calc = new CWeisWaveCalculator();
   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpATRPeriod, InpMultiplier))
     {
      Print("Error: Failed to initialize WeisWave Calculator.");
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

//--- Determine best volume array (Use Real Volume if available, otherwise fallback to Tick Volume)
   long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

//--- Safe dynamic array routing with integrated SOT flag
   if(volume_limit > 0)
     {
      g_calc.Calculate(rates_total, prev_calculated, high, low, close, volume, ExtWaveVolBuffer, ExtColorsBuffer, InpShowSOT);
     }
   else
     {
      g_calc.Calculate(rates_total, prev_calculated, high, low, close, tick_volume, ExtWaveVolBuffer, ExtColorsBuffer, InpShowSOT);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
