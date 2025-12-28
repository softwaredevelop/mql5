//+------------------------------------------------------------------+
//|                                           CCI_Oscillator_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.00" // Refactored to use CCI Engine
#property description "CCI Oscillator (Histogram of CCI vs Signal Line) with selectable"
#property description "price source (Standard and Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrLightSeaGreen
#property indicator_width1  2
#property indicator_label1  "CCI Oscillator"
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

//--- Include the calculator engine ---
#include <MyIncludes\CCI_Oscillator_Calculator.mqh>

//--- Input Parameters ---
input int                       InpCCIPeriod    = 20;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_TYPICAL_STD;
input group                     "Signal Line Settings"
input int                       InpMAPeriod     = 14;
// UPDATED: Use ENUM_MA_TYPE
input ENUM_MA_TYPE              InpMAMethod     = SMA;

//--- Indicator Buffers ---
double    BufferOscillator[];

//--- Global calculator object ---
CCCI_OscillatorCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferOscillator, INDICATOR_DATA);
   ArraySetAsSeries(BufferOscillator, false);

   g_calculator = new CCCI_OscillatorCalculator();

   bool use_ha = (InpSourcePrice <= PRICE_HA_CLOSE);

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpCCIPeriod, InpMAPeriod, InpMAMethod, use_ha))
     {
      Print("Failed to create or initialize CCI Oscillator Calculator object.");
      return(INIT_FAILED);
     }

   string type = use_ha ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CCI Osc%s(%d,%d)", type, InpCCIPeriod, InpMAPeriod));

   int draw_begin = InpCCIPeriod + InpMAPeriod - 2;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

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
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferOscillator);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
