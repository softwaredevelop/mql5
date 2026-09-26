//+------------------------------------------------------------------+
//|                                           Chart_HeikinAshi.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "4.00" // Enterprise Refactor: 5-Buffer Fused O(1) Architecture
#property description "Ultra-High Performance Heikin Ashi Candlestick Stream."
#property description "Optimized for high-density multi-chart execution with zero memory redundancy."

#property indicator_chart_window
#property indicator_buffers 5       // 4 HA Candles + 1 Color Index (45% memory reduction)
#property indicator_plots   1

//--- Plot: Heikin Ashi Candles
#property indicator_label1  "HA Open;HA High;HA Low;HA Close"
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrCornflowerBlue, clrChocolate
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Include the strictly optimized calculation engine
#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Output Buffers
double    BufferHA_Open[];
double    BufferHA_High[];
double    BufferHA_Low[];
double    BufferHA_Close[];
double    BufferColor[];

//--- Static Global Engine Instance (Zero heap allocation, zero pointer overhead)
CHeikinAshi_Calculator g_ha_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
// Map 5 Essential Indicator Buffers
   SetIndexBuffer(0, BufferHA_Open,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferHA_High,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferHA_Low,   INDICATOR_DATA);
   SetIndexBuffer(3, BufferHA_Close, INDICATOR_DATA);
   SetIndexBuffer(4, BufferColor,    INDICATOR_COLOR_INDEX);

// Strictly enforce chronological non-series indexing (0 = oldest bar)
   ArraySetAsSeries(BufferHA_Open,  false);
   ArraySetAsSeries(BufferHA_High,  false);
   ArraySetAsSeries(BufferHA_Low,   false);
   ArraySetAsSeries(BufferHA_Close, false);
   ArraySetAsSeries(BufferColor,    false);

// Configure Plot Setup
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);
   PlotIndexSetDouble(0,  PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   IndicatorSetString(INDICATOR_SHORTNAME, "Heikin Ashi Pro");

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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

// Enforce chronological indexing on input arrays
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

// Incremental start index calculation (O(1) execution)
   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : 0;

// Single-Pass Fused Execution: Computes OHLC and Color Index in a single loop
   g_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             BufferHA_Open, BufferHA_High, BufferHA_Low, BufferHA_Close,
                             BufferColor);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
