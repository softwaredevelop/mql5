//+------------------------------------------------------------------+
//|                                              RSI_HeikenAshi.mq5  |
//|            Copyright 2024, Your Name (Based on MetaQuotes RSI)   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2024, Your Name"
#property link        ""
#property version     "1.00"
#property description "RSI calculated on Heiken Ashi Close prices, with a Moving Average."

//--- Indicator settings
#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 30.0
#property indicator_level2 50.0
#property indicator_level3 70.0

//--- Buffers and Plots
#property indicator_buffers 5 // HA_RSI_MA, HA_RSI, Pos, Neg, HA_Close (all calculations)
#property indicator_plots   2 // We only plot HA_RSI_MA and HA_RSI

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

//--- Input parameters
input int            InpPeriodRSI    = 14;       // RSI Period
input int            InpPeriodMA     = 14;       // MA Period
input ENUM_MA_METHOD InpMethodMA     = MODE_SMA; // MA Method

//--- Indicator Buffers
// Plotted buffers
double    BufferHARSI_MA[]; // Smoothed Heiken Ashi RSI
double    BufferHARSI[];    // Raw Heiken Ashi RSI
// Calculation buffers
double    BufferPos[];      // For RSI calculation (average gain)
double    BufferNeg[];      // For RSI calculation (average loss)
double    BufferHAClose[];  // To store Heiken Ashi Close prices

//--- Global variables
int       ExtPeriodRSI;
int       ExtPeriodMA;

//--- Include for MA calculations
#include <MovingAverages.mqh>

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate inputs
   ExtPeriodRSI = (InpPeriodRSI < 1) ? 1 : InpPeriodRSI;
   ExtPeriodMA  = (InpPeriodMA < 1) ? 1 : InpPeriodMA;

//--- Indicator buffers mapping
   SetIndexBuffer(0, BufferHARSI_MA, INDICATOR_DATA);
   SetIndexBuffer(1, BufferHARSI,    INDICATOR_DATA);
   SetIndexBuffer(2, BufferPos,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferNeg,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferHAClose,  INDICATOR_CALCULATIONS);

//--- Set accuracy
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

//--- Set drawing start positions
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtPeriodRSI + ExtPeriodMA);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtPeriodRSI);

//--- Set labels for DataWindow
   PlotIndexSetString(0, PLOT_LABEL, "HA_RSIMA");
   PlotIndexSetString(1, PLOT_LABEL, "HA_RSI");

//--- Set indicator short name
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_RSI(%d, %d)", ExtPeriodRSI, ExtPeriodMA));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation function                            |
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
//--- Check if there is enough data
   if(rates_total < ExtPeriodRSI)
      return(0);

//====== STEP 1: CALCULATE HEIKEN ASHI BARS ======
   double ha_open, ha_close;

// Calculate the very first HA bar
   ha_open = (open[0] + close[0]) / 2.0;
   ha_close = (open[0] + high[0] + low[0] + close[0]) / 4.0;
   BufferHAClose[0] = ha_close;

// Loop to calculate all HA bars
   for(int i = 1; i < rates_total; i++)
     {
      // Previous HA values are needed
      double prev_ha_open = ha_open;
      double prev_ha_close = ha_close;

      // Calculate current HA values
      ha_close = (open[i] + high[i] + low[i] + close[i]) / 4.0;
      ha_open = (prev_ha_open + prev_ha_close) / 2.0;

      // We only need the HA Close for RSI, so we store it in our buffer
      BufferHAClose[i] = ha_close;
     }

//====== STEP 2: CALCULATE RSI BASED ON HEIKEN ASHI CLOSE PRICES ======
// This part is adapted from the standard RSI indicator code

   int start_pos;
   if(prev_calculated > 0)
      start_pos = prev_calculated - 1;
   else
      start_pos = 0;

// --- First-time calculation setup ---
   if(start_pos == 0)
     {
      double sum_pos = 0.0;
      double sum_neg = 0.0;

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
         double diff = BufferHAClose[i] - BufferHAClose[i-1];
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

// --- Main RSI calculation loop ---
   for(int i = start_pos; i < rates_total; i++)
     {
      double diff = BufferHAClose[i] - BufferHAClose[i-1];
      BufferPos[i] = (BufferPos[i-1] * (ExtPeriodRSI - 1) + (diff > 0.0 ? diff : 0.0)) / ExtPeriodRSI;
      BufferNeg[i] = (BufferNeg[i-1] * (ExtPeriodRSI - 1) + (diff < 0.0 ? -diff : 0.0)) / ExtPeriodRSI;

      if(BufferNeg[i] != 0.0)
         BufferHARSI[i] = 100.0 - 100.0 / (1.0 + BufferPos[i] / BufferNeg[i]);
      else
         BufferHARSI[i] = (BufferPos[i] != 0.0) ? 100.0 : 50.0;
     }

//====== STEP 3: CALCULATE MOVING AVERAGE ON THE HEIKEN ASHI RSI BUFFER ======
// We use the robust manual loop from our final RSIMA indicator

   if(rates_total < ExtPeriodRSI + ExtPeriodMA)
      return(rates_total); // Not enough data for MA yet

// Determine starting bar for MA calculation
   if(prev_calculated > 0)
      start_pos = prev_calculated - 1;
   else
      start_pos = ExtPeriodRSI + ExtPeriodMA - 2;

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

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
