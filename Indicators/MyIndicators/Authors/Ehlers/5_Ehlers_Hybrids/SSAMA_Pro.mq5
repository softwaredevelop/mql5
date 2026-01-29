//+------------------------------------------------------------------+
//|                                                    SSAMA_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "SuperSmoother Adaptive Moving Average (SSAMA)."
#property description "Adapts the SuperSmoother period based on market Efficiency Ratio."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "SSAMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMagenta
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\SSAMA_Calculator.mqh>

//--- Input Parameters
input group                     "Adaptive Settings"
input int                       InpErPeriod       = 10;    // Efficiency Ratio Period
input int                       InpFastPeriod     = 5;     // Min Period (Fastest/Trend)
input int                       InpSlowPeriod     = 50;    // Max Period (Slowest/Range)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;

//--- Buffers
double    BufferSSAMA[];

//--- Global Object
CSSAMACalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferSSAMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferSSAMA, false);

//--- Factory Logic
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CSSAMACalculator_HA();
   else
      g_calculator = new CSSAMACalculator();

//--- Initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpErPeriod, InpFastPeriod, InpSlowPeriod))
     {
      Print("Failed to initialize SSAMA Calculator.");
      return(INIT_FAILED);
     }

//--- Shortname
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("SSAMA%s(%d, %d-%d)", type, InpErPeriod, InpFastPeriod, InpSlowPeriod));

//--- Visuals
   int draw_begin = InpErPeriod + 2; // ER + SS lag
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

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
   if(rates_total < InpErPeriod + 2)
      return(0);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          BufferSSAMA);

   return(rates_total);
  }
//+------------------------------------------------------------------+
