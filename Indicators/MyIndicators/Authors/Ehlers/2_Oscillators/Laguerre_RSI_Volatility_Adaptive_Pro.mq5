//+------------------------------------------------------------------+
//|                      Laguerre_RSI_Volatility_Adaptive_Pro.mq5    |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Adaptive Laguerre RSI based on Volatility (MotiveWave method)."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_label1  "Vol-Adaptive LRSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumTurquoise
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLightCoral
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 10.0
#property indicator_level2 20.0
#property indicator_level3 50.0
#property indicator_level4 80.0
#property indicator_level5 90.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\Laguerre_RSI_Volatility_Calculator.mqh>

enum ENUM_LRSI_DISPLAY_MODE { DISPLAY_LRSI_ONLY, DISPLAY_LRSI_AND_SIGNAL };

//--- Input Parameters ---
input group "Volatility Settings"
input int                       InpPeriod1      = 20; // Period for Diff Range
input int                       InpPeriod2      = 5;  // Period for Alpha Median
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

input group "Signal Line Settings"
input ENUM_LRSI_DISPLAY_MODE InpDisplayMode  = DISPLAY_LRSI_AND_SIGNAL;
input int                    InpSignalPeriod = 9;
input ENUM_MA_TYPE           InpSignalMAType = EMA;

//--- Indicator Buffers ---
double    BufferLRSI[], BufferSignal[];

//--- Global calculator object ---
CLaguerreRSIVolatilityCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferLRSI,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferLRSI,   false);
   ArraySetAsSeries(BufferSignal, false);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CLaguerreRSIVolatilityCalculator_HA();
   else
      g_calculator = new CLaguerreRSIVolatilityCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod1, InpPeriod2, InpSignalPeriod, InpSignalMAType))
     {
      Print("Failed to initialize Calculator.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Vol-Adaptive LRSI%s(%d,%d)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpPeriod1, InpPeriod2));
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, MathMax(InpPeriod1, InpPeriod2));
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
int OnCalculate(const int rates_total, const int prev_calculated, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferLRSI, BufferSignal);

   if(InpDisplayMode == DISPLAY_LRSI_ONLY)
     {
      int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      for(int i = start_index; i < rates_total; i++)
         BufferSignal[i] = EMPTY_VALUE;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
