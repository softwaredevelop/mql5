//+------------------------------------------------------------------+
//|                                                         KAMA_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.10" // Optimized Single-Line KAMA
#property description "Perry Kaufman's Adaptive Moving Average (KAMA)."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Definition
#property indicator_label1  "KAMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\KAMA_Calculator.mqh>

//--- Input Parameters ---
input group                     "KAMA Core Settings"
input int                       InpErPeriod       = 10;                // Efficiency Ratio Period
input int                       InpFastEmaPeriod  = 2;                 // Fastest EMA Period
input int                       InpSlowEmaPeriod  = 30;                // Slowest EMA Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;   // Price Source (Standard / HA)

input group                     "Visual Settings"
input color                     InpColorKAMA      = clrCrimson;        // Line Color
input ENUM_LINE_STYLE           InpStyleKAMA      = STYLE_SOLID;       // Line Style
input int                       InpWidthKAMA      = 2;                 // Line Width

//--- Indicator Buffers ---
double BufferKAMA[];

//--- Global Calculator Object ---
CKamaCalculator *g_calculator = NULL;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferKAMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferKAMA, false);
   ArrayInitialize(BufferKAMA, EMPTY_VALUE);

// Configure Visuals
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorKAMA);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleKAMA);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthKAMA);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpErPeriod);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// Initialize Engine
   g_calculator = new CKamaCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpErPeriod, InpFastEmaPeriod, InpSlowEmaPeriod, InpSourcePrice))
     {
      Print("Error: Failed to initialize KAMA Calculator.");
      return INIT_FAILED;
     }

   string ha_tag = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string short_name = StringFormat("KAMA%s(%d,%d,%d)", ha_tag, InpErPeriod, InpFastEmaPeriod, InpSlowEmaPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

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
      g_calculator = NULL;
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
   if(rates_total <= InpErPeriod || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Chronological Safety
   ArraySetAsSeries(time, false);
   ArraySetAsSeries(open, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);

// High-Performance Incremental O(1) Calculation
   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferKAMA);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
