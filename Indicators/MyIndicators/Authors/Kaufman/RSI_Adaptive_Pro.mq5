//+------------------------------------------------------------------+
//|                                           RSI_Adaptive_Pro.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Added Adaptive Source Selection
#property description "Adaptive RSI with a variable period based on market volatility."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label1  "Adaptive RSI"

#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 30.0
#property indicator_level2 50.0
#property indicator_level3 70.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\RSI_Adaptive_Calculator.mqh>

//--- Input Parameters ---
input group                     "Adaptive RSI Settings"
input int                       InpPivotalPeriod = 14; // The central RSI period
input int                       InpVolaShort     = 5;  // Short period for volatility measurement
input int                       InpVolaLong      = 10; // Long period for volatility averaging
// NEW: Adaptive Source
input ENUM_ADAPTIVE_SOURCE_RSI  InpAdaptiveSource= ADAPTIVE_SOURCE_RSI_STANDARD;

input group                     "Price Source"
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice   = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferRSI[];

//--- Global calculator object ---
CAdaptiveRSICalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferRSI, INDICATOR_DATA);
   ArraySetAsSeries(BufferRSI, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CAdaptiveRSICalculator_HA();
   else
      g_calculator = new CAdaptiveRSICalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPivotalPeriod, InpVolaShort, InpVolaLong, InpAdaptiveSource))
     {
      Print("Failed to create or initialize Adaptive RSI Calculator.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Adaptive RSI%s(%d)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpPivotalPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpVolaLong + InpPivotalPeriod);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;
   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferRSI);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
