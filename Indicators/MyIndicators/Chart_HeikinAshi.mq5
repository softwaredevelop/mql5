//+------------------------------------------------------------------+
//|                                           Chart_HeikinAshi.mq5   |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "3.00" // Refactored for stability and new calculator
#property description "Draws Heikin Ashi candles on the main chart."

//--- Custom Toolkit Include ---
#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window  // Draw on the main chart window
#property indicator_buffers 5       // 4 for OHLC, 1 for color
#property indicator_plots   1

//--- Plot 1: Heikin Ashi Candles
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrCornflowerBlue, clrChocolate // Up and Down colors
#property indicator_label1  "HA Open;HA High;HA Low;HA Close" // Labels for Data Window

//--- Indicator Buffers ---
double    BufferHA_Open[];
double    BufferHA_High[];
double    BufferHA_Low[];
double    BufferHA_Close[];
double    BufferColor[];    // Buffer for candle colors

//--- Global Objects ---
CHeikinAshi_Calculator *g_ha_calculator; // Pointer to our Heikin Ashi calculator

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the buffers to the indicator's internal memory
   SetIndexBuffer(0, BufferHA_Open,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferHA_High,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferHA_Low,   INDICATOR_DATA);
   SetIndexBuffer(3, BufferHA_Close, INDICATOR_DATA);
   SetIndexBuffer(4, BufferColor,    INDICATOR_COLOR_INDEX);

//--- Set buffers to non-timeseries for stable calculation
   ArraySetAsSeries(BufferHA_Open,  false);
   ArraySetAsSeries(BufferHA_High,  false);
   ArraySetAsSeries(BufferHA_Low,   false);
   ArraySetAsSeries(BufferHA_Close, false);
   ArraySetAsSeries(BufferColor,    false);

//--- Set indicator properties
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits); // Use the same precision as the symbol
   IndicatorSetString(INDICATOR_SHORTNAME, "Heikin Ashi");
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0); // Define the empty value for the plot

//--- Create the calculator instance
   g_ha_calculator = new CHeikinAshi_Calculator();
   if(CheckPointer(g_ha_calculator) == POINTER_INVALID)
     {
      Print("Error creating CHeikinAshi_Calculator object");
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Free the calculator object to prevent memory leaks
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
     {
      delete g_ha_calculator;
      g_ha_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Heikin Ashi calculation function.                                |
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
//--- Check if there is enough historical data
   if(rates_total < 2)
      return(0);

//--- STEP 1: Calculate Heikin Ashi bars directly into the indicator buffers
   g_ha_calculator.Calculate(rates_total, open, high, low, close,
                             BufferHA_Open, BufferHA_High, BufferHA_Low, BufferHA_Close);

//--- STEP 2: Set the colors for the candles
   for(int i = 0; i < rates_total; i++)
     {
      //--- Set the color for the current candle
      // Color index 0 (clrDodgerBlue) for bullish candles
      // Color index 1 (clrMaroon) for bearish candles
      if(BufferHA_Open[i] < BufferHA_Close[i])
         BufferColor[i] = 0.0; // Bullish
      else
         BufferColor[i] = 1.0; // Bearish
     }

//--- Return value of rates_total to signal a full recalculation
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
