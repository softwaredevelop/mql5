//+------------------------------------------------------------------+
//|                                                MACD_MAMA_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "MACD based on MAMA and FAMA adaptive averages."
#property description "MACD Line = MAMA - FAMA."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Plot 1: Histogram
#property indicator_label1  "Histogram"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1

//--- Plot 2: MACD Line
#property indicator_label2  "MACD"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: Signal Line
#property indicator_label3  "Signal"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

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
double    BufferMACD[];
double    BufferSignal[];

//--- Global Object
CMACDMAMACalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferHistogram, INDICATOR_DATA);
   SetIndexBuffer(1, BufferMACD,      INDICATOR_DATA);
   SetIndexBuffer(2, BufferSignal,    INDICATOR_DATA);
   ArraySetAsSeries(BufferHistogram, false);
   ArraySetAsSeries(BufferMACD,      false);
   ArraySetAsSeries(BufferSignal,    false);

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
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MACD MAMA%s(%.2f, %.2f, %s %d)", type, InpFastLimit, InpSlowLimit, EnumToString(InpSignalMethod), InpSignalPeriod));

//--- Visuals
   int draw_begin = 50; // MAMA needs warmup
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, draw_begin + InpSignalPeriod);
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

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          BufferMACD, BufferSignal, BufferHistogram);

   return(rates_total);
  }
//+------------------------------------------------------------------+
