//+------------------------------------------------------------------+
//|                                        VIDYA_TrendActivity_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "5.02" // Adapted to new ATR Calculator
#property description "Measures the trend activity of a VIDYA line with selectable sources."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2
#property indicator_label1  "Activity"
#property indicator_minimum 0.0
#property indicator_maximum 0.5

#include <MyIncludes\VIDYA_TrendActivity_Calculator.mqh>

//--- Input Parameters ---
input group                     "VIDYA Settings"
input int                       InpPeriodCMO    = 9;
input int                       InpPeriodEMA    = 12;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;
input group                     "Activity Calculation Settings"
input int                       InpAtrPeriod    = 14;
//--- UPDATED: Use the standard candle source enum ---
input ENUM_CANDLE_SOURCE        InpAtrSource    = CANDLE_STANDARD;
input int                       InpSmoothingPeriod = 5;

//--- Indicator Buffers ---
double    BufferActivity[];

//--- Global calculator object ---
CVIDYATrendActivityCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferActivity, INDICATOR_DATA);
   ArraySetAsSeries(BufferActivity, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CVIDYATrendActivityCalculator_HA();
   else
      g_calculator = new CVIDYATrendActivityCalculator();

//--- UPDATED: Pass the correct enum type ---
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriodCMO, InpPeriodEMA, InpAtrPeriod, InpAtrSource, InpSmoothingPeriod))
     {
      Print("Failed to create or initialize VIDYA Trend Activity Calculator object.");
      return(INIT_FAILED);
     }

   int draw_begin = InpPeriodCMO + InpPeriodEMA + InpAtrPeriod + InpSmoothingPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
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
//| Custom indicator calculation function.                           |
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

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferActivity);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
