//+------------------------------------------------------------------+
//|                                 WeisWave_CumulativeDelta_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Non-repainting state-machine, O(1) optimized
#property description "Weis Wave Cumulative Delta (Smart Money Flow Indicator)"
#property description "Tracks the rolling cumulative difference of buy vs sell waves."
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Plot: Color Line (Rising = Green, Falling = Red)
#property indicator_label1  "Cumulative Delta"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLimeGreen, clrCrimson // Index 0: Rising, Index 1: Falling
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\WeisWave_CumulativeDelta_Calculator.mqh>

//--- Input Parameters
input int    InpATRPeriod = 14;   // ATR Sensitivity Period
input double InpMultiplier = 2.5;  // Wave Reversal Multiplier (ATR)

//--- Buffers
double ExtDeltaBuffer[];
double ExtColorsBuffer[];

//--- Global Engine
CWeisWaveDeltaCalculator *g_calc;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, ExtDeltaBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtColorsBuffer, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(ExtDeltaBuffer, false);
   ArraySetAsSeries(ExtColorsBuffer, false);

   string short_name = StringFormat("Weis Wave Cumulative Delta Pro(%d, %.1f)", InpATRPeriod, InpMultiplier);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, 0);

   g_calc = new CWeisWaveDeltaCalculator();
   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpATRPeriod, InpMultiplier))
     {
      Print("Error: Failed to initialize Cumulative Delta Calculator.");
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

//--- Determine best volume array (Use Real Volume if available, otherwise fallback to Tick Volume)
   long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

//--- Safe dynamic array routing to engine
   if(volume_limit > 0)
     {
      g_calc.Calculate(rates_total, prev_calculated, high, low, close, volume, ExtDeltaBuffer, ExtColorsBuffer);
     }
   else
     {
      g_calc.Calculate(rates_total, prev_calculated, high, low, close, tick_volume, ExtDeltaBuffer, ExtColorsBuffer);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
