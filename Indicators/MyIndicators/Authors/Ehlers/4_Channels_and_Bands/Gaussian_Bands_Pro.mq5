//+------------------------------------------------------------------+
//|                                           Gaussian_Bands_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Bollinger-style bands using an Ehlers Gaussian Filter as the centerline."

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

#property indicator_label1  "Upper"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSeaGreen
#property indicator_label2  "Lower"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSeaGreen
#property indicator_label3  "Middle"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSeaGreen

#include <MyIncludes\Gaussian_Bands_Calculator.mqh>

//--- Input Parameters ---
input int                       InpPeriod      = 20;
input double                    InpMultiplier  = 2.0;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferUpper[], BufferLower[], BufferMiddle[];

//--- Global calculator object ---
CGaussianBandsCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferUpper,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferLower,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferMiddle, INDICATOR_DATA);
   ArraySetAsSeries(BufferUpper, false);
   ArraySetAsSeries(BufferLower, false);
   ArraySetAsSeries(BufferMiddle, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CGaussianBandsCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Gaussian Bands HA(%d,%.1f)", InpPeriod, InpMultiplier));
     }
   else
     {
      g_calculator = new CGaussianBandsCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Gaussian Bands(%d,%.1f)", InpPeriod, InpMultiplier));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpMultiplier))
     {
      Print("Failed to initialize Gaussian Bands Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpPeriod);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, InpPeriod);
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

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferUpper, BufferLower, BufferMiddle);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
