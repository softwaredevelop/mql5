//+------------------------------------------------------------------+
//|                                              RSI_HeikenAshi.mq5  |
//|             Copyright 2025, xxxxxxxx (Based on MetaQuotes RSI)   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2025, xxxxxxxx"
#property link        ""
#property version     "2.00" // Refactored to use HA_Tools.mqh
#property description "RSI on Heiken Ashi prices, with a Moving Average."

// --- Standard Includes ---
#include <MovingAverages.mqh>
// --- Custom Toolkit Includes ---
#include <MyIncludes\HA_Tools.mqh>

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 30.0
#property indicator_level2 50.0
#property indicator_level3 70.0

//--- Buffers and Plots ---
#property indicator_buffers 4 // HA_RSI_MA, HA_RSI, Pos, Neg
#property indicator_plots   2

//--- Plot 1: RSI MA line (smoothed)
#property indicator_label1  "HA_RSIMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: RSI line (raw)
#property indicator_label2  "HA_RSI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGreen
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Input Parameters ---
input int            InpPeriodRSI    = 14;       // RSI Period
input int            InpPeriodMA     = 14;       // MA Period
input ENUM_MA_METHOD InpMethodMA     = MODE_SMA; // MA Method

//--- Indicator Buffers ---
// Plotted buffers
double    BufferHARSI_MA[]; // Smoothed Heiken Ashi RSI
double    BufferHARSI[];    // Raw Heiken Ashi RSI
// Calculation buffers
double    BufferPos[];      // For RSI calculation (average gain)
double    BufferNeg[];      // For RSI calculation (average loss)

//--- Global Objects and Variables ---
int              ExtPeriodRSI;
int              ExtPeriodMA;
CHA_Calculator   g_ha_calculator; // Global instance of our Heiken Ashi calculator

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//| Called once when the indicator is first loaded.                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate and store input periods
   ExtPeriodRSI = (InpPeriodRSI < 1) ? 1 : InpPeriodRSI;
   ExtPeriodMA  = (InpPeriodMA < 1) ? 1 : InpPeriodMA;

//--- Map the buffers to the indicator's internal memory
   SetIndexBuffer(0, BufferHARSI_MA, INDICATOR_DATA);
   SetIndexBuffer(1, BufferHARSI,    INDICATOR_DATA);
   SetIndexBuffer(2, BufferPos,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferNeg,      INDICATOR_CALCULATIONS);

//--- Set indicator properties
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtPeriodRSI + ExtPeriodMA - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtPeriodRSI);
   PlotIndexSetString(0, PLOT_LABEL, "HA_RSIMA");
   PlotIndexSetString(1, PLOT_LABEL, "HA_RSI");
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_RSI(%d, %d)", ExtPeriodRSI, ExtPeriodMA));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation function.                           |
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
   if(rates_total < ExtPeriodRSI)
      return(0);

//--- STEP 1: Calculate Heiken Ashi bars using our toolkit
   if(!g_ha_calculator.Calculate(rates_total, prev_calculated, open, high, low, close))
     {
      Print("Heiken Ashi calculation failed.");
      return(0);
     }

//--- STEP 2: Calculate RSI based on the Heiken Ashi Close prices
   int start_pos;
   if(prev_calculated > 0)
      start_pos = prev_calculated - 1;
   else
      start_pos = 0;

//--- First-time calculation setup
   if(start_pos == 0)
     {
      double sum_pos = 0.0, sum_neg = 0.0;
      // Initialize first period values to zero
      for(int i = 0; i < ExtPeriodRSI; i++)
        {
         BufferHARSI[i] = 0.0;
         BufferPos[i] = 0.0;
         BufferNeg[i] = 0.0;
        }
      // Calculate initial sums for the first visible RSI value
      for(int i = 1; i <= ExtPeriodRSI; i++)
        {
         // Use the HA Close from our calculator object
         double diff = g_ha_calculator.ha_close[i] - g_ha_calculator.ha_close[i-1];
         sum_pos += (diff > 0 ? diff : 0);
         sum_neg += (diff < 0 ? -diff : 0);
        }
      // Calculate first visible value
      BufferPos[ExtPeriodRSI] = sum_pos / ExtPeriodRSI;
      BufferNeg[ExtPeriodRSI] = sum_neg / ExtPeriodRSI;
      if(BufferNeg[ExtPeriodRSI] != 0.0)
         BufferHARSI[ExtPeriodRSI] = 100.0 - (100.0 / (1.0 + BufferPos[ExtPeriodRSI] / BufferNeg[ExtPeriodRSI]));
      else
         BufferHARSI[ExtPeriodRSI] = (BufferPos[ExtPeriodRSI] != 0.0) ? 100.0 : 50.0;
      // Set the starting position for the main loop
      start_pos = ExtPeriodRSI + 1;
     }

//--- Main RSI calculation loop
   for(int i = start_pos; i < rates_total; i++)
     {
      // Use the HA Close from our calculator object
      double diff = g_ha_calculator.ha_close[i] - g_ha_calculator.ha_close[i-1];
      BufferPos[i] = (BufferPos[i-1] * (ExtPeriodRSI - 1) + (diff > 0.0 ? diff : 0.0)) / ExtPeriodRSI;
      BufferNeg[i] = (BufferNeg[i-1] * (ExtPeriodRSI - 1) + (diff < 0.0 ? -diff : 0.0)) / ExtPeriodRSI;

      if(BufferNeg[i] != 0.0)
         BufferHARSI[i] = 100.0 - 100.0 / (1.0 + BufferPos[i] / BufferNeg[i]);
      else
         BufferHARSI[i] = (BufferPos[i] != 0.0) ? 100.0 : 50.0;
     }

//--- STEP 3: Calculate Moving Average on the Heiken Ashi RSI buffer
   if(rates_total < ExtPeriodRSI + ExtPeriodMA)
      return(rates_total);

// Determine starting bar for MA calculation
   if(prev_calculated > 0)
      start_pos = prev_calculated - 1;
   else
      start_pos = ExtPeriodRSI + ExtPeriodMA - 2;

// The MA functions need non-timeseries arrays
   ArraySetAsSeries(BufferHARSI, false);

// Loop through bars that need MA calculation
   for(int i = start_pos; i < rates_total; i++)
     {
      if(i < ExtPeriodRSI + ExtPeriodMA - 2)
        {
         BufferHARSI_MA[i] = EMPTY_VALUE;
         continue;
        }
      switch(InpMethodMA)
        {
         case MODE_EMA:
            BufferHARSI_MA[i] = ExponentialMA(i, ExtPeriodMA, BufferHARSI_MA[i-1], BufferHARSI);
            break;
         case MODE_SMMA:
            BufferHARSI_MA[i] = SmoothedMA(i, ExtPeriodMA, BufferHARSI_MA[i-1], BufferHARSI);
            break;
         case MODE_LWMA:
            BufferHARSI_MA[i] = LinearWeightedMA(i, ExtPeriodMA, BufferHARSI);
            break;
         default: // MODE_SMA
            BufferHARSI_MA[i] = SimpleMA(i, ExtPeriodMA, BufferHARSI);
            break;
        }
     }
// Restore timeseries property for the next call
   ArraySetAsSeries(BufferHARSI, true);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
