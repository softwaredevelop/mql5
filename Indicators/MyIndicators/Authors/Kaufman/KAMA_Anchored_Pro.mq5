//+------------------------------------------------------------------+
//|                                          KAMA_Anchored_Pro.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Upgraded with dynamic odd/even gapped segment drawing
#property description "Kaufman's Adaptive Moving Average with dynamic Anchored Resets."
#property description "Resets its calculation baseline on specific calendar events to prevent connecting line drag."

#property indicator_chart_window
#property indicator_buffers 2 // Two buffers for gapped drawing
#property indicator_plots   2

//--- Plot 1: KAMA Line (Odd Periods)
#property indicator_label1  "KAMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepPink
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: KAMA Line (Even Periods)
#property indicator_label2  "KAMA (Segment)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDeepPink
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#include <MyIncludes\KAMA_Anchored_Calculator.mqh>

//--- Input Parameters ---
input group "KAMA Settings"
input int                       InpErPeriod       = 10;        // Efficiency Ratio Period
input int                       InpFastEmaPeriod  = 2;         // Fastest EMA Period
input int                       InpSlowEmaPeriod  = 30;        // Slowest EMA Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD; // Price Source

input group "Anchor Settings"
input ENUM_ANCHOR_PERIOD        InpAnchor         = ANCHOR_SESSION;  // Reset Anchor Period
input string                    InpCustomStart    = "09:00";   // Custom Session Start (HH:MM)
input string                    InpCustomEnd      = "18:00";   // Custom Session End (HH:MM)

//--- Indicator Buffers ---
double    BufferKAMA_Odd[];
double    BufferKAMA_Even[];

//--- Global calculator object ---
CKamaAnchoredCalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferKAMA_Odd,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferKAMA_Even, INDICATOR_DATA);
   ArraySetAsSeries(BufferKAMA_Odd,  false);
   ArraySetAsSeries(BufferKAMA_Even, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- Factory Logic
   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CKamaAnchoredCalculator_HA();
     }
   else
     {
      g_calculator = new CKamaAnchoredCalculator();
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpErPeriod, InpFastEmaPeriod, InpSlowEmaPeriod, InpAnchor, InpCustomStart, InpCustomEnd))
     {
      Print("Failed to initialize KAMA Anchored Calculator.");
      return(INIT_FAILED);
     }

//--- Shortname
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string anchor_name = EnumToString(InpAnchor);
   string short_name = StringFormat("KAMA Anch%s(%s,%d)", type, StringSubstr(anchor_name, 7), InpErPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpErPeriod);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpErPeriod);

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
   if(rates_total < InpErPeriod + 5)
      return(0);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Force standard chronological indexing for state-safety
   ArraySetAsSeries(time, false);
   ArraySetAsSeries(open, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);

   g_calculator.Calculate(rates_total, prev_calculated, price_type, time, open, high, low, close, BufferKAMA_Odd, BufferKAMA_Even);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
