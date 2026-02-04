//+------------------------------------------------------------------+
//|                                                  Squeeze_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Professional Volatility Squeeze Indicator."
#property description "Identifies periods of consolidation before breakouts."

#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   2

//--- Plot 1: Momentum Histogram
#property indicator_label1  "Momentum"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrDodgerBlue, clrCrimson, clrDeepSkyBlue, clrFireBrick
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Squeeze State (Dots on Zero Line)
#property indicator_label2  "Squeeze State"
#property indicator_type2   DRAW_COLOR_ARROW
#property indicator_color2  clrLime, clrRed // Green=OFF (Action), Red=ON (Squeeze)
#property indicator_width2  2

//--- Includes
#include <MyIncludes\Squeeze_Calculator.mqh>

//--- Input Parameters
input group             "Squeeze Settings"
input int               InpPeriod      = 20;    // Length combined
input double            InpBBMult      = 2.0;   // Bollinger Multiplier
input double            InpKCMult      = 1.5;   // Keltner Multiplier
input ENUM_APPLIED_PRICE InpPrice      = PRICE_CLOSE;

input group             "Momentum Settings"
input int               InpMomPeriod   = 12;    // Momentum/Regression Period
// Optional: Method for momentum smoothing could be added here

//--- Buffers
double BufferMom[];
double BufferSqueeze[]; // Value (always 0)
double BufferSqueezeColors[]; // Color Index

//--- Global Object
CSqueezeCalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
// 1. Buffer Mapping
   SetIndexBuffer(0, BufferMom, INDICATOR_DATA);
   SetIndexBuffer(1, BufferSqueeze, INDICATOR_DATA);
   SetIndexBuffer(2, BufferSqueezeColors, INDICATOR_COLOR_INDEX);

// Internal buffers for calculation handled by class, but MT5 needs buffers decl logic?
// No, Class handles internal arrays. We only map visual buffers here.

// 2. Visual Setup
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod);

   PlotIndexSetInteger(1, PLOT_ARROW, 159); // Dot character
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpPeriod);

// 3. Name
   string name = StringFormat("SqueezePro(%d, BB:%.1f, KC:%.1f)", InpPeriod, InpBBMult, InpKCMult);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

// 4. Init Calculator
   g_calculator = new CSqueezeCalculator();
   if(!g_calculator.Init(InpPeriod, InpBBMult, InpKCMult, InpMomPeriod))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) == POINTER_DYNAMIC)
      delete g_calculator;
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
   if(rates_total < InpPeriod)
      return 0;

// Delegate directly to the calculator engine
// Colors for Squeeze: 0=Green (No Squeeze), 1=Red (Squeeze IS ON)
   g_calculator.Calculate(rates_total, prev_calculated, InpPrice,
                          open, high, low, close,
                          BufferMom, BufferSqueeze, BufferSqueezeColors);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
