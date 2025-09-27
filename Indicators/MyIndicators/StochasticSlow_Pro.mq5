//+------------------------------------------------------------------+
//|                                           StochasticSlow_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "3.10"
#property description "Professional Stochastic with selectable MA types and price source."

#include <MyIncludes\Stochastic_Calculator.mqh>

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_level1 20.0
#property indicator_level2 80.0
#property indicator_minimum 0.0
#property indicator_maximum 100.0

//--- Plot 1: %K line (Slow)
#property indicator_label1  "%K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: %D line (Signal)
#property indicator_label2  "%D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Custom Enum for Price Source
enum ENUM_PRICE_SOURCE_TYPE
  {
   PRICE_SOURCE_STANDARD,     // Use standard OHLC prices
   PRICE_SOURCE_HEIKIN_ASHI   // Use Heikin Ashi prices
  };

//--- Input Parameters ---
input int                    InpKPeriod       = 5;
input int                    InpSlowingPeriod = 3;
input ENUM_MA_METHOD         InpSlowingMethod = MODE_SMA;
input int                    InpDPeriod       = 3;
input ENUM_MA_METHOD         InpDMethod       = MODE_SMA;
input ENUM_PRICE_SOURCE_TYPE InpPriceSource   = PRICE_SOURCE_STANDARD;

//--- Indicator Buffers ---
double    BufferK[];
double    BufferD[];

//--- Global calculator object (as a base class pointer) ---
CStochasticCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferK, INDICATOR_DATA);
   SetIndexBuffer(1, BufferD, INDICATOR_DATA);

   ArraySetAsSeries(BufferK, false);
   ArraySetAsSeries(BufferD, false);

//--- Dynamic Calculator Instantiation based on the new enum
   if(InpPriceSource == PRICE_SOURCE_HEIKIN_ASHI)
     {
      g_calculator = new CStochasticCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Stoch Pro HA(%d,%d,%d)", InpKPeriod, InpSlowingPeriod, InpDPeriod));
     }
   else
     {
      g_calculator = new CStochasticCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Stoch Pro(%d,%d,%d)", InpKPeriod, InpSlowingPeriod, InpDPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpKPeriod, InpSlowingPeriod, InpDPeriod, InpSlowingMethod, InpDMethod))
     {
      Print("Failed to initialize Stochastic Calculator.");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   int draw_begin = InpKPeriod + InpSlowingPeriod + InpDPeriod - 3;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpKPeriod + InpSlowingPeriod - 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);

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
      g_calculator.Calculate(rates_total, open, high, low, close, BufferK, BufferD);
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
