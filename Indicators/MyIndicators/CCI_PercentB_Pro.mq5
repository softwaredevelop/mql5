//+------------------------------------------------------------------+
//|                                           CCI_PercentB_Pro.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Refactored to use CCI Engine
#property description "RSI %B. Shows the position of the RSI line relative to its Bollinger Bands."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_level1 0.0
#property indicator_level2 50
#property indicator_level3 100
#property indicator_levelstyle STYLE_DOT
#property indicator_minimum -10.0
#property indicator_maximum 110.0

#include <MyIncludes\CCI_PercentB_Calculator.mqh>

//--- Plot 1: %B Line
#property indicator_label1  "CCI %B"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumPurple
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Input Parameters ---
input group                     "CCI Settings"
input int                       InpCCIPeriod    = 20;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_TYPICAL_STD;
input group                     "Overlay Settings"
input int                       InpMAPeriod     = 14; // Used as BBands center line
// UPDATED: Use ENUM_MA_TYPE
input ENUM_MA_TYPE              InpMAMethod     = SMA; // Used as BBands center line
input int                       InpBandsPeriod  = 14;
input double                    InpBandsDev     = 2.0;

//--- Buffers ---
double    BufferPercentB[];

//--- Global calculator ---
CCCI_PercentBCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferPercentB, INDICATOR_DATA);
   ArraySetAsSeries(BufferPercentB, false);

   g_calculator = new CCCI_PercentBCalculator();

   bool use_ha = (InpSourcePrice <= PRICE_HA_CLOSE);

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpCCIPeriod, InpMAPeriod, InpMAMethod, InpBandsPeriod, InpBandsDev, use_ha))
     {
      Print("Failed to create or initialize CCI PercentB Calculator object.");
      return(INIT_FAILED);
     }

   string type = use_ha ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CCI %%B%s(%d)", type, InpCCIPeriod));

   int draw_begin = InpCCIPeriod + InpBandsPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
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

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferPercentB);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
