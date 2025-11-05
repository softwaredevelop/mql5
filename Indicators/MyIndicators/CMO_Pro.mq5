//+------------------------------------------------------------------+
//|                                                      CMO_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Chande Momentum Oscillator (CMO) with selectable"
#property description "price source (Standard and Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label1  "CMO"

//--- Indicator Levels ---
#property indicator_level1 50.0
#property indicator_level2 0.0
#property indicator_level3 -50.0
#property indicator_levelstyle STYLE_DOT

//--- Include the calculator engine ---
#include <MyIncludes\CMO_Calculator.mqh>

//--- Input Parameters ---
input int                       InpPeriodCMO    = 14;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferCMO[];

//--- Global calculator object (as a base class pointer) ---
CCMOCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferCMO, INDICATOR_DATA);
   ArraySetAsSeries(BufferCMO, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CCMOCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CMO HA(%d)", InpPeriodCMO));
     }
   else
     {
      g_calculator = new CCMOCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CMO(%d)", InpPeriodCMO));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriodCMO))
     {
      Print("Failed to create or initialize CMO Calculator object.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriodCMO);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

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

//--- Determine the price type from the unified enum ---
   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferCMO);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
