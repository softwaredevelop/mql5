//+------------------------------------------------------------------+
//|                                        McGinleyDynamic_Pro.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "3.10" // Final robust version with internal state management
#property description "Professional McGinley Dynamic Indicator with selectable"
#property description "price source (Standard and Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: McGinley Dynamic line
#property indicator_label1  "McGinley"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Include the calculator engine ---
#include <MyIncludes\McGinleyDynamic_Calculator.mqh>

//--- Input Parameters ---
input int                       InpLength       = 14;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferMcGinley[];

//--- Global calculator object (as a base class pointer) ---
CMcGinleyDynamicCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMcGinley, INDICATOR_DATA);
   ArraySetAsSeries(BufferMcGinley, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CMcGinleyDynamicCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("McGinley HA(%d)", InpLength));
     }
   else
     {
      g_calculator = new CMcGinleyDynamicCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("McGinley(%d)", InpLength));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpLength))
     {
      Print("Failed to create or initialize McGinley Dynamic Calculator object.");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpLength - 1);

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

   g_calculator.Calculate(rates_total, open, high, low, close, price_type, BufferMcGinley);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
