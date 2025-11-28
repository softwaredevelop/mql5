//+------------------------------------------------------------------+
//|                                           Chart_HeikinAshi.mq5   |
//|                      Copyright 2025, xxxxxxxx                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.05" // Refactored to strict 10-param calculation
#property description "Draws Heikin Ashi candles on the main chart."

//--- Include the strict, optimized toolkit
#include <MyIncludes\HeikinAshi_Tools.mqh>

#property indicator_chart_window
#property indicator_buffers 9       // 4 HA + 1 Color + 4 Hidden
#property indicator_plots   2

//--- Plot 1: Heikin Ashi Candles
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrCornflowerBlue, clrChocolate
#property indicator_label1  "HA Open;HA High;HA Low;HA Close"
#property indicator_width1  1

//--- Plot 2: Main Price Series (Hidden)
//--- Used to keep the chart scaled correctly to the real price, even if HA differs slightly
#property indicator_type2   DRAW_NONE
#property indicator_label2  "OHLC"

//--- Buffers
double    BufferHA_Open[];
double    BufferHA_High[];
double    BufferHA_Low[];
double    BufferHA_Close[];
double    BufferColor[];

double    BufferMain_Open[];
double    BufferMain_High[];
double    BufferMain_Low[];
double    BufferMain_Close[];

//--- Global Calculator
CHeikinAshi_Calculator *g_ha_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map HA Buffers
   SetIndexBuffer(0, BufferHA_Open,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferHA_High,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferHA_Low,   INDICATOR_DATA);
   SetIndexBuffer(3, BufferHA_Close, INDICATOR_DATA);
   SetIndexBuffer(4, BufferColor,    INDICATOR_COLOR_INDEX);

//--- Map Hidden Buffers
   SetIndexBuffer(5, BufferMain_Open,  INDICATOR_DATA);
   SetIndexBuffer(6, BufferMain_High,  INDICATOR_DATA);
   SetIndexBuffer(7, BufferMain_Low,   INDICATOR_DATA);
   SetIndexBuffer(8, BufferMain_Close, INDICATOR_DATA);

//--- Drawing settings
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);

//--- CRITICAL: Set all arrays as non-timeseries for standard 0..total indexing
   ArraySetAsSeries(BufferHA_Open,  false);
   ArraySetAsSeries(BufferHA_High,  false);
   ArraySetAsSeries(BufferHA_Low,   false);
   ArraySetAsSeries(BufferHA_Close, false);
   ArraySetAsSeries(BufferColor,    false);
   ArraySetAsSeries(BufferMain_Open,  false);
   ArraySetAsSeries(BufferMain_High,  false);
   ArraySetAsSeries(BufferMain_Low,   false);
   ArraySetAsSeries(BufferMain_Close, false);

//--- Indicator Info
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   IndicatorSetString(INDICATOR_SHORTNAME, "Heikin Ashi Pro");

//--- Initialize Calculator
   g_ha_calculator = new CHeikinAshi_Calculator();
   if(CheckPointer(g_ha_calculator) == POINTER_INVALID)
      return(INIT_FAILED);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
      delete g_ha_calculator;
  }

//+------------------------------------------------------------------+
//| Iteration function                                               |
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

//--- 1. Determine Start Index (Optimization Logic)
   int start_index;

   if(prev_calculated == 0)
     {
      start_index = 0;
     }
   else
     {
      // Start from the last calculated bar to update it as it forms
      start_index = prev_calculated - 1;
     }

//--- 2. Copy Hidden Data (Optimized Loop)
//--- Instead of ArrayCopy for the whole history, we only update the new bars
   for(int i = start_index; i < rates_total; i++)
     {
      BufferMain_Open[i]  = open[i];
      BufferMain_High[i]  = high[i];
      BufferMain_Low[i]   = low[i];
      BufferMain_Close[i] = close[i];
     }

//--- 3. Calculate Heikin Ashi (Strict 10-Parameter Call)
//--- We explicitly pass 'start_index' to comply with the new tool signature
   g_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             BufferHA_Open, BufferHA_High, BufferHA_Low, BufferHA_Close);

//--- 4. Update Colors (Optimized Loop)
   for(int i = start_index; i < rates_total; i++)
     {
      // Simple logic: Bullish if Close > Open
      if(BufferHA_Close[i] > BufferHA_Open[i])
         BufferColor[i] = 0; // Bullish Color (clrCornflowerBlue)
      else
         BufferColor[i] = 1; // Bearish Color (clrChocolate)
     }

//--- Return new rates_total for the next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
