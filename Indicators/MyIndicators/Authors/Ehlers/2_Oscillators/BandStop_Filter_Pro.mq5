//+------------------------------------------------------------------+
//|                                          BandStop_Filter_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.10" // CORRECTED: Changed to separate window for proper visualization
#property description "John Ehlers' Band-Stop Filter to remove a specific market cycle."

// CORRECTED: Changed to a separate window
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "BandStop"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrOrange
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\BandStop_Calculator.mqh>

//--- Input Parameters ---
input int                       InpPeriod       = 20;    // Center Period of the cycle to remove
input double                    InpBandwidth    = 0.1;   // Bandwidth of the removed cycle (0.05 to 0.5)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferFilter[];

//--- Global calculator object ---
CBandStopCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferFilter,  INDICATOR_DATA);
   ArraySetAsSeries(BufferFilter,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CBandStopCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("BandStop HA(%d,%.2f)", InpPeriod, InpBandwidth));
     }
   else
     {
      g_calculator = new CBandStopCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("BandStop(%d,%.2f)", InpPeriod, InpBandwidth));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpBandwidth))
     {
      Print("Failed to initialize Band-Stop Filter Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 3);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

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

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferFilter);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
