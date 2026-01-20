//+------------------------------------------------------------------+
//|                                           TSI_Oscillator_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "4.00" // Updated to use unified calculator
#property description "TSI Oscillator (Histogram of TSI vs Signal Line) with selectable"
#property description "price source (Standard and Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1
#property indicator_label1  "TSI Oscillator"

//--- Include the calculator engine ---
#include <MyIncludes\TSI_Calculator.mqh>

//--- Input Parameters ---
input group                     "TSI Calculation Settings"
input int                       InpSlowPeriod   = 25;
input ENUM_MA_TYPE              InpSlowMAType   = EMA;
input int                       InpFastPeriod   = 13;
input ENUM_MA_TYPE              InpFastMAType   = EMA;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

input group                     "Signal Line Settings"
input int                       InpSignalPeriod = 13;
input ENUM_MA_TYPE              InpSignalMAType = EMA;

//--- Indicator Buffers ---
double    BufferOscillator[];

//--- Global calculator object ---
CTSICalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferOscillator, INDICATOR_DATA);
   ArraySetAsSeries(BufferOscillator, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CTSICalculator_HA();
   else
      g_calculator = new CTSICalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpSlowPeriod, InpSlowMAType, InpFastPeriod, InpFastMAType, InpSignalPeriod, InpSignalMAType))
     {
      Print("Failed to create or initialize TSI Calculator object.");
      return(INIT_FAILED);
     }

   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("TSI Osc%s(%d,%d,%d)", type, InpSlowPeriod, InpFastPeriod, InpSignalPeriod));

   int draw_begin = InpSlowPeriod + InpFastPeriod + InpSignalPeriod - 1;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

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

   g_calculator.CalculateOscillatorOnly(rates_total, prev_calculated, price_type, open, high, low, close, BufferOscillator);

   return(rates_total);
  }
//+------------------------------------------------------------------+
