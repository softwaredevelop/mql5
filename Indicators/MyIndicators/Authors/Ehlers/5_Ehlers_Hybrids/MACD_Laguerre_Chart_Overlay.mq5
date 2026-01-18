//+------------------------------------------------------------------+
//|                                  MACD_Laguerre_Chart_Overlay.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Overlays the two Laguerre Filters used by the Laguerre MACD."
#property description "Visualizes the Fast and Slow components directly on the price chart."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Fast Laguerre
#property indicator_label1  "Fast Laguerre"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Slow Laguerre
#property indicator_label2  "Slow Laguerre"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrFireBrick
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\Laguerre_Engine.mqh>

//--- Input Parameters
input double                    InpGamma1       = 0.5; // Fast Gamma (smaller value = faster)
input double                    InpGamma2       = 0.8; // Slow Gamma (larger value = slower)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Buffers
double    BufferFast[];
double    BufferSlow[];

//--- Global calculator objects
CLaguerreEngine *g_fast_engine;
CLaguerreEngine *g_slow_engine;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferFast, INDICATOR_DATA);
   SetIndexBuffer(1, BufferSlow, INDICATOR_DATA);

   ArraySetAsSeries(BufferFast, false);
   ArraySetAsSeries(BufferSlow, false);

//--- Determine actual Fast/Slow gammas (just in case user swaps them)
   double fast_gamma = MathMin(InpGamma1, InpGamma2);
   double slow_gamma = MathMax(InpGamma1, InpGamma2);

//--- Factory Logic
   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_fast_engine = new CLaguerreEngine_HA();
      g_slow_engine = new CLaguerreEngine_HA();

      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Laguerre MACD Overlay HA(%.2f, %.2f)", fast_gamma, slow_gamma));
     }
   else
     {
      g_fast_engine = new CLaguerreEngine();
      g_slow_engine = new CLaguerreEngine();

      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Laguerre MACD Overlay(%.2f, %.2f)", fast_gamma, slow_gamma));
     }

//--- Initialize Engines
   if(CheckPointer(g_fast_engine) == POINTER_INVALID || !g_fast_engine.Init(fast_gamma, SOURCE_PRICE))
     {
      Print("Failed to initialize Fast Laguerre Engine.");
      return(INIT_FAILED);
     }

   if(CheckPointer(g_slow_engine) == POINTER_INVALID || !g_slow_engine.Init(slow_gamma, SOURCE_PRICE))
     {
      Print("Failed to initialize Slow Laguerre Engine.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 2);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_fast_engine) != POINTER_INVALID)
      delete g_fast_engine;
   if(CheckPointer(g_slow_engine) != POINTER_INVALID)
      delete g_slow_engine;
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
   if(rates_total < 2)
      return(0);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Calculate Fast Laguerre
   g_fast_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, BufferFast);

//--- Calculate Slow Laguerre
   g_slow_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, BufferSlow);

   return(rates_total);
  }
//+------------------------------------------------------------------+
