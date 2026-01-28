//+------------------------------------------------------------------+
//|                                           MACD_MAMA_Line_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "MACD Line based on MAMA and FAMA adaptive averages."
#property description "Displays only the MACD Line (MAMA - FAMA)."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: MACD Line
#property indicator_label1  "MACD Line"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_level1  0.0

#include <MyIncludes\MACD_MAMA_Calculator.mqh>

//--- Input Parameters
input group                     "MAMA Settings"
input double                    InpFastLimit    = 0.5;   // Fast Limit
input double                    InpSlowLimit    = 0.05;  // Slow Limit
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Buffers
double    BufferMACD[];

//--- Global Object
CMACDMAMACalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMACD, INDICATOR_DATA);
   ArraySetAsSeries(BufferMACD, false);

//--- Factory Logic
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMACDMAMACalculator_HA();
   else
      g_calculator = new CMACDMAMACalculator();

//--- Initialize
// Note: Signal params are dummy here (9, SMA) as we only need the MACD Line
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpFastLimit, InpSlowLimit, 9, SMA))
     {
      Print("Failed to initialize MACD MAMA Calculator.");
      return(INIT_FAILED);
     }

//--- Shortname
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MACD MAMA Line%s(%.2f, %.2f)", type, InpFastLimit, InpSlowLimit));

//--- Visuals
   int draw_begin = 50; // MAMA needs warmup
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

   g_calculator.CalculateMACDLineOnly(rates_total, prev_calculated, price_type, open, high, low, close,
                                      BufferMACD);

   return(rates_total);
  }
//+------------------------------------------------------------------+
