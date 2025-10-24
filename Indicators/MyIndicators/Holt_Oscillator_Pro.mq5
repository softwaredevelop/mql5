//+------------------------------------------------------------------+
//|                                           Holt_Oscillator_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.01" // Final unified architecture
#property description "Holt's Trend Oscillator. Shows the smoothed trend component."
#property description "Supports Standard and Heikin Ashi price sources."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_level1 0.0
#property indicator_levelstyle STYLE_DOT
#property indicator_levelcolor clrGray

//--- Include the calculator engine ---
#include <MyIncludes\Holt_Oscillator_Calculator.mqh>

//--- Plot 1: Holt Trend Oscillator
#property indicator_label1  "Holt Trend"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSeaGreen, clrTomato
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int                       InpPeriod      = 20;
input double                    InpAlpha       = 0.1;
input double                    InpBeta        = 0.05;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferOscillator[];

//--- Global calculator object (as a base class pointer) ---
CHoltOscillatorCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferOscillator, INDICATOR_DATA);
   ArraySetAsSeries(BufferOscillator, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CHoltOscillatorCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Holt Osc HA(%d)", InpPeriod));
     }
   else
     {
      g_calculator = new CHoltOscillatorCalculator_Std();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Holt Osc(%d)", InpPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpAlpha, InpBeta))
     {
      Print("Failed to initialize Holt Oscillator Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits+2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function.                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferOscillator);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
