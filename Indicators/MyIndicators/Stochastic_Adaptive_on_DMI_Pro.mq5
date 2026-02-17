//+------------------------------------------------------------------+
//|                               Stochastic_Adaptive_on_DMI_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.00" // Pure DMI-based Adaptivity
#property description "Adaptive Stochastic applied to DMI Oscillator."
#property description "Adapts lookback based on DMI's own volatility."

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

#include <MyIncludes\Stochastic_Adaptive_on_DMI_Calculator.mqh>

//--- Input Parameters
input group                     "DMI Settings"
input int                       InpDMIPeriod     = 10;
input ENUM_DMI_OSC_TYPE         InpOscType       = OSC_PDI_MINUS_NDI;

input group                     "Adaptive Settings"
input int                       InpErPeriod      = 10;   // Efficiency Ratio Period
input int                       InpMinStochPeriod= 5;    // Min Dynamic Period
input int                       InpMaxStochPeriod= 30;   // Max Dynamic Period

input group                     "Stochastic Settings"
input int                       InpSlowingPeriod = 3;
input ENUM_MA_TYPE              InpSlowingMAType = SMA;
input int                       InpDPeriod       = 3;
input ENUM_MA_TYPE              InpDMAType       = SMA;

input group                     "Price Source"
input ENUM_CANDLE_SOURCE        InpCandleSource  = CANDLE_STANDARD; // Controls DMI Input

//--- Buffers
double    BufferK[], BufferD[];

//--- Global Object
CStochAdaptiveOnDMICalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferK, INDICATOR_DATA);
   SetIndexBuffer(1, BufferD, INDICATOR_DATA);
   ArraySetAsSeries(BufferK, false);
   ArraySetAsSeries(BufferD, false);

// Factory Logic based on Source
   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
      g_calculator = new CStochAdaptiveOnDMICalculator_HA();
   else
      g_calculator = new CStochAdaptiveOnDMICalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpDMIPeriod, InpOscType, InpErPeriod, InpMinStochPeriod, InpMaxStochPeriod, InpSlowingPeriod, InpSlowingMAType, InpDPeriod, InpDMAType))
     {
      Print("Failed to initialize Calculator.");
      return(INIT_FAILED);
     }

   string name = StringFormat("StochAdaptiveDMI(%d, ER:%d)", InpDMIPeriod, InpErPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   int draw_begin = InpDMIPeriod + InpErPeriod + InpMaxStochPeriod + InpSlowingPeriod + InpDPeriod;
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

// We pass standard OHLC, the HA calculator will convert internally if needed
   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferK, BufferD);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
