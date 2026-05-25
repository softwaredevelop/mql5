//+------------------------------------------------------------------+
//|                                                     VWMA_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.20" // Optimized for incremental calculation
#property description "Volume-Weighted Moving Average (VWMA) Professional Indicator"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "VWMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\VWMA_Calculator.mqh>

//--- Input Parameters ---
input int                       InpPeriod      = 20; // Lookback Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD; // Price Source

//--- Indicator Buffers ---
double    BufferVWMA[];

//--- Global calculator object ---
CVWMA_Calculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferVWMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferVWMA, false);

//--- Factory instantiation based on Price Source (Standard vs Heikin Ashi)
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CVWMA_Calculator_HA();
   else
      g_calculator = new CVWMA_Calculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod))
     {
      Print("Failed to initialize VWMA Calculator.");
      return(INIT_FAILED);
     }

//--- Dynamic name initialization
   string short_name = StringFormat("VWMA%s(%d)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpPeriod);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, short_name);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      delete g_calculator;
     }
  }

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
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

//--- Convert custom HA price mapping back to standard ENUM_APPLIED_PRICE
   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Determine the best volume array to use (MQL5 Standard)
   long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

//--- Safe dynamic array routing without local array reference variables
   if(volume_limit > 0)
     {
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, volume, BufferVWMA);
     }
   else
     {
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, tick_volume, BufferVWMA);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
