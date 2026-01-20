//+------------------------------------------------------------------+
//|                                           MACD_Histogram_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Histogram for the MACD with a selectable signal line."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

#property indicator_label1  "Histogram"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1
//#property indicator_level1  0.0
//#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\MACD_Calculator.mqh>

//--- Input Parameters
input int                       InpFastPeriod   = 12;
input int                       InpSlowPeriod   = 26;
input int                       InpSignalPeriod = 9;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;
input ENUM_MA_TYPE              InpSourceMAType = EMA;
input ENUM_MA_TYPE              InpSignalMAType = EMA;

//--- Indicator Buffers
double    BufferHistogram[];

//--- Global calculator object
CMACDCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferHistogram, INDICATOR_DATA);
   ArraySetAsSeries(BufferHistogram, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMACDCalculator_HA();
   else
      g_calculator = new CMACDCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpFastPeriod, InpSlowPeriod, InpSignalPeriod, InpSourceMAType, InpSignalMAType))
     {
      Print("Failed to create or initialize MACD Calculator.");
      return(INIT_FAILED);
     }

   string short_name = StringFormat("MACD Histo%s(%d,%d,%d)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpFastPeriod, InpSlowPeriod, InpSignalPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, MathMax(InpFastPeriod, InpSlowPeriod) + InpSignalPeriod);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

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

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.CalculateHistogramOnly(rates_total, prev_calculated, open, high, low, close, price_type, BufferHistogram);

   return(rates_total);
  }
//+------------------------------------------------------------------+
