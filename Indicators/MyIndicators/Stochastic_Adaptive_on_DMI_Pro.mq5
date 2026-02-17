//+------------------------------------------------------------------+
//|                               Stochastic_Adaptive_on_DMI_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.01"
#property description "Adaptive Stochastic Oscillator applied to DMI."
#property description "Dynamically adjusts lookback based on DMI volatility."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Main %K
#property indicator_label1  "Adaptive %K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal %D
#property indicator_label2  "Adaptive %D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrCoral
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Levels
#property indicator_level1 20.0
#property indicator_level2 80.0
#property indicator_level3 50.0
#property indicator_minimum 0.0
#property indicator_maximum 100.0

//--- Includes (Fixed: Correct path)
#include <MyIncludes\Stochastic_Adaptive_on_DMI_Calculator.mqh>

//--- Input Parameters
input group                     "Source Settings"
// Declared in Calculator.mqh now
input ENUM_CANDLE_SOURCE        InpCandleSource  = CANDLE_STANDARD;
input ENUM_DMI_ADAPTIVE_OSC_TYPE InpOscType      = OSC_PDI_MINUS_NDI;
input int                       InpDMIPeriod     = 14;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group                     "Adaptive Logic (ER)"
input int                       InpERPeriod      = 10;   // Efficiency Ratio Period
input int                       InpMinStochPeriod= 5;    // Min Dynamic Period
input int                       InpMaxStochPeriod= 30;   // Max Dynamic Period

input group                     "Smoothing"
input int                       InpSlowingK      = 3;    // %K Slowing Period
input ENUM_MA_TYPE              InpSlowingMethod = SMA;  // %K Method
input int                       InpSignalD       = 3;    // %D Period
input ENUM_MA_TYPE              InpSignalMethod  = SMA;  // %D Method

//--- Buffers
double BufferK[];
double BufferD[];

//--- Calculator
CStochAdaptiveOnDMICalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
// 1. Buffer Mapping
   SetIndexBuffer(0, BufferK, INDICATOR_DATA);
   SetIndexBuffer(1, BufferD, INDICATOR_DATA);
   ArraySetAsSeries(BufferK, false);
   ArraySetAsSeries(BufferD, false);

// 2. Initialize Engine
   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
      g_calculator = new CStochAdaptiveOnDMICalculator_HA();
   else
      g_calculator = new CStochAdaptiveOnDMICalculator();

   if(!g_calculator.Init(InpDMIPeriod, InpERPeriod, InpMinStochPeriod, InpMaxStochPeriod,
                         InpSlowingK, InpSlowingMethod, InpSignalD, InpSignalMethod, InpOscType))
     {
      Print("Init Failed.");
      return(INIT_FAILED);
     }

// 3. Metadata
   string name = StringFormat("StochAdaptiveDMI(%d, ER:%d, Dyn:%d-%d)",
                              InpDMIPeriod, InpERPeriod, InpMinStochPeriod, InpMaxStochPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   int draw_begin = InpDMIPeriod + InpERPeriod + InpMaxStochPeriod + InpSlowingK + InpSignalD;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);

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
   if(rates_total < InpDMIPeriod + InpMaxStochPeriod)
      return 0;

   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferK, BufferD);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
