//+------------------------------------------------------------------+
//|                                    MACD_MAMA_Histogram_Pro.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Histogram for the MAMA MACD."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: Histogram
#property indicator_label1  "Histogram"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1

#include <MyIncludes\MACD_MAMA_Calculator.mqh>

//--- Input Parameters
input group                     "MAMA Settings"
input double                    InpFastLimit    = 0.5;   // Fast Limit
input double                    InpSlowLimit    = 0.05;  // Slow Limit
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

input group                     "Signal Line Settings"
input int                       InpSignalPeriod = 9;
input ENUM_MA_TYPE              InpSignalMethod = SMA;

//--- Buffers
double    BufferHistogram[];

//--- Global Object
CMACDMAMACalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferHistogram, INDICATOR_DATA);
   ArraySetAsSeries(BufferHistogram, false);

//--- Factory Logic
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMACDMAMACalculator_HA();
   else
      g_calculator = new CMACDMAMACalculator();

//--- Initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpFastLimit, InpSlowLimit, InpSignalPeriod, InpSignalMethod))
     {
      Print("Failed to initialize MACD MAMA Calculator.");
      return(INIT_FAILED);
     }

//--- Shortname
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MACD MAMA Histo%s(%.2f, %.2f, %d)", type, InpFastLimit, InpSlowLimit, InpSignalPeriod));

//--- Visuals
   int draw_begin = 50 + InpSignalPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 1);

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
   if(rates_total < 50)
      return(0);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.CalculateHistogramOnly(rates_total, prev_calculated, price_type, open, high, low, close,
                                       BufferHistogram);

   return(rates_total);
  }
//+------------------------------------------------------------------+
