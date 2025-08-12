//+------------------------------------------------------------------+
//|                                             Chart_HeikenAshi.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored to use HA_Tools.mqh
#property description "Draws Heiken Ashi candles on the main chart."

//--- Custom Toolkit Include ---
#include <MyIncludes\HA_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window  // Draw on the main chart window
#property indicator_buffers 5       // 4 for OHLC, 1 for color
#property indicator_plots   1

//--- Plot 1: Heiken Ashi Candles
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrDodgerBlue, clrMaroon // Up and Down colors
#property indicator_label1  "HA Open;HA High;HA Low;HA Close" // Labels for Data Window

//--- Indicator Buffers ---
double    BufferHA_Open[];
double    BufferHA_High[];
double    BufferHA_Low[];
double    BufferHA_Close[];
double    BufferColor[];    // Buffer for candle colors

//--- Global Objects ---
CHA_Calculator g_ha_calculator; // Global instance of our Heiken Ashi calculator

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//| Called once when the indicator is first loaded.                  |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- Map the buffers to the indicator's internal memory
   SetIndexBuffer(0, BufferHA_Open,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferHA_High,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferHA_Low,   INDICATOR_DATA);
   SetIndexBuffer(3, BufferHA_Close, INDICATOR_DATA);
   SetIndexBuffer(4, BufferColor,    INDICATOR_COLOR_INDEX);

//--- Set indicator properties
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits); // Use the same precision as the symbol
   IndicatorSetString(INDICATOR_SHORTNAME, "Heiken Ashi");
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0); // Define the empty value for the plot
  }

//+------------------------------------------------------------------+
//| Heiken Ashi calculation function.                                |
//| Called on every new tick or new bar.                             |
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

//--- STEP 1: Calculate Heiken Ashi bars using our toolkit
// We use a full recalculation (prev_calculated=0) for maximum stability
   if(!g_ha_calculator.Calculate(rates_total, 0, open, high, low, close))
     {
      Print("Heiken Ashi calculation failed in OnCalculate.");
      return(0);
     }

//--- STEP 2: Copy data from the calculator and set colors
// The main loop iterates through all bars to ensure data consistency
   for(int i = 0; i < rates_total; i++)
     {
      // Copy the calculated HA values from our toolkit to the indicator's buffers
      BufferHA_Open[i]  = g_ha_calculator.ha_open[i];
      BufferHA_High[i]  = g_ha_calculator.ha_high[i];
      BufferHA_Low[i]   = g_ha_calculator.ha_low[i];
      BufferHA_Close[i] = g_ha_calculator.ha_close[i];

      //--- Set the color for the current candle
      // Color index 0 (clrDodgerBlue) for bullish candles
      // Color index 1 (clrMaroon) for bearish candles
      if(BufferHA_Open[i] < BufferHA_Close[i])
         BufferColor[i] = 0.0; // Bullish
      else
         BufferColor[i] = 1.0; // Bearish
     }

//--- Return value of prev_calculated for the next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
