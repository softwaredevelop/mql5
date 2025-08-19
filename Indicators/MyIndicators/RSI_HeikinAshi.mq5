//+------------------------------------------------------------------+
//|                                             RSI_HeikinAshi.mq5   |
//|            Copyright 2025, xxxxxxxx (Based on MetaQuotes RSI)    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2025, xxxxxxxx"
#property link        ""
#property version     "4.00" // Refactored for full recalculation and stability
#property description "RSI on Heikin Ashi prices, with a Moving Average."

// --- Standard and Custom Includes ---
#include <MovingAverages.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 30.0
#property indicator_level2 50.0
#property indicator_level3 70.0

//--- Buffers and Plots ---
#property indicator_buffers 4 // 2 for plotting, 2 for RSI calculations
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
input int            InpPeriodRSI    = 14;       // Period for RSI calculation
input int            InpPeriodMA     = 14;       // Period for Moving Average smoothing
input ENUM_MA_METHOD InpMethodMA     = MODE_SMA; // Method for Moving Average smoothing

//--- Indicator Buffers ---
double    BufferHARSI_MA[]; // Plotted buffer for the smoothed RSI line
double    BufferHARSI[];    // Plotted buffer for the raw Heikin Ashi RSI line
double    BufferPos[];      // Calculation buffer for RSI's average gain
double    BufferNeg[];      // Calculation buffer for RSI's average loss

//--- Intermediate Heikin Ashi Buffers ---
double    ExtHaOpenBuffer[];
double    ExtHaHighBuffer[];
double    ExtHaLowBuffer[];
double    ExtHaCloseBuffer[];

//--- Global Objects and Variables ---
int                       g_ExtPeriodRSI;
int                       g_ExtPeriodMA;
CHeikinAshi_Calculator   *g_ha_calculator; // Pointer to our Heikin Ashi calculator

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate and store input periods
   g_ExtPeriodRSI = (InpPeriodRSI < 1) ? 1 : InpPeriodRSI;
   g_ExtPeriodMA  = (InpPeriodMA < 1) ? 1 : InpPeriodMA;

//--- Map the buffers
   SetIndexBuffer(0, BufferHARSI_MA, INDICATOR_DATA);
   SetIndexBuffer(1, BufferHARSI,    INDICATOR_DATA);
   SetIndexBuffer(2, BufferPos,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferNeg,      INDICATOR_CALCULATIONS);

//--- Set all buffers as non-timeseries
   ArraySetAsSeries(BufferHARSI_MA, false);
   ArraySetAsSeries(BufferHARSI,    false);
   ArraySetAsSeries(BufferPos,      false);
   ArraySetAsSeries(BufferNeg,      false);

//--- Set indicator display properties
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtPeriodRSI + g_ExtPeriodMA - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtPeriodRSI);
   PlotIndexSetString(0, PLOT_LABEL, "HA_RSIMA");
   PlotIndexSetString(1, PLOT_LABEL, "HA_RSI");
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_RSI(%d, %d)", g_ExtPeriodRSI, g_ExtPeriodMA));

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
//--- Free the calculator object
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
     {
      delete g_ha_calculator;
      g_ha_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation function.                           |
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
   if(rates_total <= g_ExtPeriodRSI)
      return(0);

//--- Resize intermediate buffers
   ArrayResize(ExtHaOpenBuffer, rates_total);
   ArrayResize(ExtHaHighBuffer, rates_total);
   ArrayResize(ExtHaLowBuffer, rates_total);
   ArrayResize(ExtHaCloseBuffer, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close,
                             ExtHaOpenBuffer, ExtHaHighBuffer, ExtHaLowBuffer, ExtHaCloseBuffer);

//--- STEP 2: Calculate RSI on HA Close in a single, robust loop
   for(int i = 1; i < rates_total; i++)
     {
      double diff = ExtHaCloseBuffer[i] - ExtHaCloseBuffer[i-1];
      double positive_change = (diff > 0) ? diff : 0;
      double negative_change = (diff < 0) ? -diff : 0;

      if(i == g_ExtPeriodRSI)
        {
         double sum_pos=0, sum_neg=0;
         for(int j=1; j<=g_ExtPeriodRSI; j++)
           {
            double p_diff = ExtHaCloseBuffer[j] - ExtHaCloseBuffer[j-1];
            sum_pos += (p_diff > 0) ? p_diff : 0;
            sum_neg += (p_diff < 0) ? -p_diff : 0;
           }
         BufferPos[i] = sum_pos / g_ExtPeriodRSI;
         BufferNeg[i] = sum_neg / g_ExtPeriodRSI;
        }
      else
         if(i > g_ExtPeriodRSI)
           {
            BufferPos[i] = (BufferPos[i-1] * (g_ExtPeriodRSI - 1) + positive_change) / g_ExtPeriodRSI;
            BufferNeg[i] = (BufferNeg[i-1] * (g_ExtPeriodRSI - 1) + negative_change) / g_ExtPeriodRSI;
           }

      if(i >= g_ExtPeriodRSI)
        {
         if(BufferNeg[i] > 0)
           {
            double rs = BufferPos[i] / BufferNeg[i];
            BufferHARSI[i] = 100.0 - (100.0 / (1.0 + rs));
           }
         else
           {
            BufferHARSI[i] = 100.0;
           }
        }
     }

//--- STEP 3: Calculate Moving Average on the HA RSI buffer
// --- FIX: Correct starting position for the MA calculation ---
   int ma_start_pos = g_ExtPeriodRSI + g_ExtPeriodMA - 1;

   for(int i = ma_start_pos; i < rates_total; i++)
     {
      switch(InpMethodMA)
        {
         case MODE_EMA:
            if(i == ma_start_pos)
              {
               // Manual SMA for initialization on non-timeseries array
               double sum = 0;
               for(int j = 0; j < g_ExtPeriodMA; j++)
                 {
                  sum += BufferHARSI[i - j];
                 }
               BufferHARSI_MA[i] = sum / g_ExtPeriodMA;
              }
            else
              {
               double pr = 2.0 / (g_ExtPeriodMA + 1.0);
               BufferHARSI_MA[i] = BufferHARSI[i] * pr + BufferHARSI_MA[i-1] * (1.0 - pr);
              }
            break;
         case MODE_SMMA:
            if(i == ma_start_pos)
              {
               // Manual SMA for initialization on non-timeseries array
               double sum = 0;
               for(int j = 0; j < g_ExtPeriodMA; j++)
                 {
                  sum += BufferHARSI[i - j];
                 }
               BufferHARSI_MA[i] = sum / g_ExtPeriodMA;
              }
            else
               BufferHARSI_MA[i] = (BufferHARSI_MA[i-1] * (g_ExtPeriodMA - 1) + BufferHARSI[i]) / g_ExtPeriodMA;
            break;
         case MODE_LWMA:
            BufferHARSI_MA[i] = LinearWeightedMA(i, g_ExtPeriodMA, BufferHARSI);
            break;
         default: // MODE_SMA
            BufferHARSI_MA[i] = SimpleMA(i, g_ExtPeriodMA, BufferHARSI);
            break;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
