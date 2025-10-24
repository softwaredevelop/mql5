//+------------------------------------------------------------------+
//|                                     Bollinger_ATR_Oscillator.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.01"
#property description "Bollinger Bands ATR Oscillator by Jon Anderson."
#property description "Includes a full range of standard and Heikin Ashi price sources."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

#include <MyIncludes\Bollinger_ATR_Oscillator_Calculator.mqh>

//--- Plot 1: Oscillator Line
#property indicator_label1  "BB ATR Ratio"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumTurquoise
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Input Parameters ---
input int                      InpAtrPeriod    = 22;
input int                      InpBandsPeriod  = 55;
input double                   InpBandsDev     = 2.0;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferOscillator[];

//--- Global calculator object ---
CBollingerATROscillatorCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferOscillator, INDICATOR_DATA);
   ArraySetAsSeries(BufferOscillator, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CBollingerATROscillatorCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("BB_ATR_Osc HA(%d, %d)", InpAtrPeriod, InpBandsPeriod));
     }
   else
     {
      g_calculator = new CBollingerATROscillatorCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("BB_ATR_Osc(%d, %d)", InpAtrPeriod, InpBandsPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpAtrPeriod, InpBandsPeriod, InpBandsDev))
     {
      Print("Failed to initialize Bollinger ATR Oscillator Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, MathMax(InpAtrPeriod, InpBandsPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 4);

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
   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      ENUM_APPLIED_PRICE price_type;
      if(InpSourcePrice <= PRICE_HA_CLOSE)
         price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
      else
         price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

      g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferOscillator);
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
