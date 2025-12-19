//+------------------------------------------------------------------+
//|                                             StochRSI_Fast_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.20" // Refactored to use MovingAverage_Engine
#property description "Professional Fast Stochastic RSI with selectable MA type and"
#property description "price source (Standard or Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 2 // %K and %D
#property indicator_plots   2
#property indicator_level1 20.0
#property indicator_level2 50.0
#property indicator_level3 80.0
#property indicator_minimum -10.0
#property indicator_maximum 110.0

//--- Plot 1: %K line
#property indicator_label1  "%K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: %D line
#property indicator_label2  "%D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrCoral
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Include the calculator engine ---
#include <MyIncludes\StochRSI_Fast_Calculator.mqh>

//--- Input Parameters ---
input group                     "Stochastic RSI Settings"
input int                       InpRSIPeriod     = 14;
input int                       InpKPeriod       = 14;
input int                       InpDPeriod       = 3;
input group                     "MA & Price Settings"
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice   = PRICE_CLOSE_STD;
// UPDATED: Use ENUM_MA_TYPE
input ENUM_MA_TYPE              InpDMAType       = SMA;

//--- Indicator Buffers ---
double    BufferK[];
double    BufferD[];

//--- Global calculator object ---
CStochRSI_Fast_Calculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferK, INDICATOR_DATA);
   SetIndexBuffer(1, BufferD, INDICATOR_DATA);
   ArraySetAsSeries(BufferK, false);
   ArraySetAsSeries(BufferD, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CStochRSI_Fast_Calculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("StochRSI Fast HA(%d,%d,%s)", InpRSIPeriod, InpKPeriod, EnumToString(InpDMAType)));
     }
   else
     {
      g_calculator = new CStochRSI_Fast_Calculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("StochRSI Fast(%d,%d,%s)", InpRSIPeriod, InpKPeriod, EnumToString(InpDMAType)));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpRSIPeriod, InpKPeriod, InpDPeriod, InpDMAType))
     {
      Print("Failed to create or initialize StochRSI Fast Calculator object.");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   int draw_begin_k = InpRSIPeriod + InpKPeriod - 2;
   int draw_begin_d = draw_begin_k + InpDPeriod - 1;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin_k);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin_d);

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
//| Custom indicator calculation function                            |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, price_type, BufferK, BufferD);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
