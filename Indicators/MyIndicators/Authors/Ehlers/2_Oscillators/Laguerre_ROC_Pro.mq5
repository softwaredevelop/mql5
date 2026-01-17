//+------------------------------------------------------------------+
//|                                             Laguerre_ROC_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Laguerre Rate of Change (ROC). Measures the slope or percentage change"
#property description "of the Laguerre Filter to identify trend momentum and reversals."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: ROC Line
#property indicator_label1  "ROC"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal Line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Zero Line
#property indicator_level1 0.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\Laguerre_ROC_Calculator.mqh>

//--- Input Parameters
input group                     "Laguerre Settings"
input double                    InpGamma         = 0.7;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice   = PRICE_CLOSE_STD;

input group                     "ROC Settings"
input ENUM_ROC_MODE             InpROCMode       = ROC_POINTS; // Calculation Mode
input int                       InpSignalPeriod  = 3;          // Signal Line Period
input ENUM_MA_TYPE              InpSignalMethod  = SMA;        // Signal Line Method

//--- Buffers
double    BufferROC[];
double    BufferSignal[];

//--- Global Object
CLaguerreROCCalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferROC,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferROC,    false);
   ArraySetAsSeries(BufferSignal, false);

//--- Factory Logic
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CLaguerreROCCalculator_HA();
   else
      g_calculator = new CLaguerreROCCalculator();

//--- Initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpGamma, InpSignalPeriod, InpSignalMethod))
     {
      Print("Failed to initialize Laguerre ROC Calculator.");
      return(INIT_FAILED);
     }

//--- Shortname
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string modeStr = (InpROCMode == ROC_POINTS) ? "Points" : "Percent";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Laguerre ROC%s(%s, %.2f)", type, modeStr, InpGamma));

//--- Visuals
// Set precision based on mode
   if(InpROCMode == ROC_PERCENT)
      IndicatorSetInteger(INDICATOR_DIGITS, 2);
   else
      IndicatorSetInteger(INDICATOR_DIGITS, _Digits); // Points mode needs price precision

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 2 + InpSignalPeriod);

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
   if(rates_total < 2)
      return(0);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          InpROCMode, BufferROC, BufferSignal);

   return(rates_total);
  }
//+------------------------------------------------------------------+
