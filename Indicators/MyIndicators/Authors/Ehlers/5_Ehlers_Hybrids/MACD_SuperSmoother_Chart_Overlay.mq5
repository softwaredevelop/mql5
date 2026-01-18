//+------------------------------------------------------------------+
//|                             MACD_SuperSmoother_Chart_Overlay.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Overlays the two SuperSmoother Filters used by the SS MACD."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Fast SS
#property indicator_label1  "Fast SS"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Slow SS
#property indicator_label2  "Slow SS"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrFireBrick
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>

//--- Input Parameters
input int                       InpFastPeriod   = 12;
input int                       InpSlowPeriod   = 26;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Buffers
double    BufferFast[];
double    BufferSlow[];

//--- Global calculator objects
CEhlersSmootherCalculator *g_fast_calc;
CEhlersSmootherCalculator *g_slow_calc;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferFast, INDICATOR_DATA);
   SetIndexBuffer(1, BufferSlow, INDICATOR_DATA);
   ArraySetAsSeries(BufferFast, false);
   ArraySetAsSeries(BufferSlow, false);

   int fast = MathMin(InpFastPeriod, InpSlowPeriod);
   int slow = MathMax(InpFastPeriod, InpSlowPeriod);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_fast_calc = new CEhlersSmootherCalculator_HA();
      g_slow_calc = new CEhlersSmootherCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("SS MACD Overlay HA(%d, %d)", fast, slow));
     }
   else
     {
      g_fast_calc = new CEhlersSmootherCalculator();
      g_slow_calc = new CEhlersSmootherCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("SS MACD Overlay(%d, %d)", fast, slow));
     }

   if(CheckPointer(g_fast_calc) == POINTER_INVALID || !g_fast_calc.Init(fast, SUPERSMOOTHER, SOURCE_PRICE))
      return INIT_FAILED;
   if(CheckPointer(g_slow_calc) == POINTER_INVALID || !g_slow_calc.Init(slow, SUPERSMOOTHER, SOURCE_PRICE))
      return INIT_FAILED;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, fast);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, slow);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_fast_calc) != POINTER_INVALID)
      delete g_fast_calc;
   if(CheckPointer(g_slow_calc) != POINTER_INVALID)
      delete g_slow_calc;
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
   if(rates_total < 2)
      return(0);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_fast_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferFast);
   g_slow_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferSlow);

   return(rates_total);
  }
//+------------------------------------------------------------------+
