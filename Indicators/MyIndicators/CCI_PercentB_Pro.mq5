//+------------------------------------------------------------------+
//|                                           CCI_PercentB_Pro.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "PercentB Oscillator for the CCI Pro indicator. Shows the CCI's"
#property description "position relative to its Bollinger Bands."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_level1 0.0
#property indicator_level2 50.0
#property indicator_level3 100.0
#property indicator_levelstyle STYLE_DOT
#property indicator_minimum -10.0
#property indicator_maximum 110.0

#include <MyIncludes\CCI_PercentB_Calculator.mqh>

#property indicator_label1  "%B"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue

//--- Input Parameters ---
input group                     "CCI Settings"
input int                       InpCCIPeriod    = 20;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_TYPICAL_STD;
input group                     "Overlay Settings"
input int                       InpMAPeriod     = 14; // Used as BBands center line
input ENUM_MA_METHOD            InpMAMethod     = MODE_SMA; // Used as BBands center line
input int                       InpBandsPeriod  = 14;
input double                    InpBandsDev     = 2.0;

//--- Buffers ---
double    BufferPercentB[];

//--- Global calculator ---
CCCI_PercentBCalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferPercentB, INDICATOR_DATA);
   ArraySetAsSeries(BufferPercentB, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CCCI_PercentBCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CCI %%B HA(%d)", InpCCIPeriod));
     }
   else
     {
      g_calculator = new CCCI_PercentBCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CCI %%B(%d)", InpCCIPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpCCIPeriod, InpMAPeriod, InpMAMethod, InpBandsPeriod, InpBandsDev))
     {
      Print("Failed to create or initialize CCI PercentB Calculator object.");
      return(INIT_FAILED);
     }

   int draw_begin = InpCCIPeriod + InpBandsPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
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

   g_calculator.Calculate(rates_total, open, high, low, close, price_type, BufferPercentB);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
