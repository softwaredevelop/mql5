//+------------------------------------------------------------------+
//|                                          WPRMA_HeikinAshi.mq5    |
//|            Copyright 2025, xxxxxxxx (Based on MetaQuotes WPR)    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2025, xxxxxxxx"
#property link        ""
#property version     "2.02" // Reverted to robust manual MA calculation
#property description "WPR on Heikin Ashi candles, with a Moving Average."

// --- Standard and Custom Includes ---
#include <MovingAverages.mqh> // For SimpleMA and LinearWeightedMA single-value functions
#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_level1     -20.0
#property indicator_level2     -80.0
#property indicator_levelstyle STYLE_DOT
#property indicator_levelcolor clrSilver
#property indicator_levelwidth 1
#property indicator_maximum    0.0
#property indicator_minimum    -100.0

//--- Buffers and Plots ---
#property indicator_buffers    2 // WPRMA and the raw WPR
#property indicator_plots      2

//--- Plot 1: WPR MA line (smoothed)
#property indicator_label1     "HA_WPRMA"
#property indicator_type1      DRAW_LINE
#property indicator_color1     clrRed

//--- Plot 2: WPR line (raw)
#property indicator_label2     "HA_WPR"
#property indicator_type2      DRAW_LINE
#property indicator_color2     clrDodgerBlue

//--- Input Parameters ---
input int            InpWPRPeriod = 14;       // Period for WPR calculation
input int            InpMAPeriod  = 14;       // Period for Moving Average
input ENUM_MA_METHOD InpMAMethod  = MODE_SMA; // Method for Moving Average

//--- Indicator Buffers ---
double    BufferHA_WPRMA[]; // Buffer for the smoothed WPR line
double    BufferHA_WPR[];   // Buffer for the raw Heikin Ashi WPR line

//--- Intermediate Heikin Ashi Buffers ---
double    ExtHaOpenBuffer[];
double    ExtHaHighBuffer[];
double    ExtHaLowBuffer[];
double    ExtHaCloseBuffer[];

//--- Global Objects and Variables ---
int                       g_ExtWPRPeriod;
int                       g_ExtMAPeriod;
CHeikinAshi_Calculator   *g_ha_calculator; // Pointer to our Heikin Ashi calculator

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate and store input periods
   g_ExtWPRPeriod = (InpWPRPeriod < 1) ? 1 : InpWPRPeriod;
   g_ExtMAPeriod  = (InpMAPeriod < 1) ? 1 : InpMAPeriod;

//--- Map the buffers
   SetIndexBuffer(0, BufferHA_WPRMA, INDICATOR_DATA);
   SetIndexBuffer(1, BufferHA_WPR,   INDICATOR_DATA);

//--- Set buffers to non-timeseries for stable calculation
   ArraySetAsSeries(BufferHA_WPRMA, false);
   ArraySetAsSeries(BufferHA_WPR,   false);

//--- Set indicator properties
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtWPRPeriod + g_ExtMAPeriod - 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtWPRPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_WPRMA(%d, %d)", g_ExtWPRPeriod, g_ExtMAPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

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
//| Williams’ Percent Range on Heikin Ashi with MA.                  |
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
//--- Check if there is enough historical data for the first calculation
   if(rates_total < g_ExtWPRPeriod)
      return(0);

//--- Resize intermediate buffers to match the available bars
   ArrayResize(ExtHaOpenBuffer, rates_total);
   ArrayResize(ExtHaHighBuffer, rates_total);
   ArrayResize(ExtHaLowBuffer, rates_total);
   ArrayResize(ExtHaCloseBuffer, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars using our toolkit (full recalculation)
   g_ha_calculator.Calculate(rates_total, open, high, low, close,
                             ExtHaOpenBuffer, ExtHaHighBuffer, ExtHaLowBuffer, ExtHaCloseBuffer);

//--- STEP 2: Calculate the raw WPR based on the Heikin Ashi results
   for(int i = g_ExtWPRPeriod - 1; i < rates_total; i++)
     {
      double max_ha_high = Highest(ExtHaHighBuffer, g_ExtWPRPeriod, i);
      double min_ha_low  = Lowest(ExtHaLowBuffer, g_ExtWPRPeriod, i);
      if(max_ha_high != min_ha_low)
         BufferHA_WPR[i] = - (max_ha_high - ExtHaCloseBuffer[i]) * 100.0 / (max_ha_high - min_ha_low);
      else
         BufferHA_WPR[i] = (i > 0) ? BufferHA_WPR[i-1] : -50.0;
     }

//--- STEP 3: Calculate the Moving Average on the raw WPR buffer using a manual loop
   int ma_start_pos = g_ExtWPRPeriod + g_ExtMAPeriod - 2;
   for(int i = ma_start_pos; i < rates_total; i++)
     {
      switch(InpMAMethod)
        {
         case MODE_EMA:
            // --- Special handling for EMA ---
            if(i == ma_start_pos) // First EMA value is an SMA
              {
               BufferHA_WPRMA[i] = SimpleMA(i, g_ExtMAPeriod, BufferHA_WPR);
              }
            else // Subsequent EMA values are calculated recursively
              {
               double pr = 2.0 / (g_ExtMAPeriod + 1.0);
               BufferHA_WPRMA[i] = BufferHA_WPR[i] * pr + BufferHA_WPRMA[i-1] * (1.0 - pr);
              }
            break;

         case MODE_SMMA:
            if(i == ma_start_pos) // First SMMA value is an SMA
              {
               BufferHA_WPRMA[i] = SimpleMA(i, g_ExtMAPeriod, BufferHA_WPR);
              }
            else // Subsequent SMMA values are calculated recursively
              {
               BufferHA_WPRMA[i] = (BufferHA_WPRMA[i-1] * (g_ExtMAPeriod - 1) + BufferHA_WPR[i]) / g_ExtMAPeriod;
              }
            break;

         case MODE_LWMA:
            BufferHA_WPRMA[i] = LinearWeightedMA(i, g_ExtMAPeriod, BufferHA_WPR);
            break;

         default: // MODE_SMA
            BufferHA_WPRMA[i] = SimpleMA(i, g_ExtMAPeriod, BufferHA_WPR);
            break;
        }
     }

//--- Return value of rates_total to signal a full recalculation
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Finds the highest value in a given period of an array.           |
//+------------------------------------------------------------------+
double Highest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res < array[index])
         res = array[index];
     }
   return(res);
  }

//+------------------------------------------------------------------+
//| Finds the lowest value in a given period of an array.            |
//+------------------------------------------------------------------+
double Lowest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res > array[index])
         res = array[index];
     }
   return(res);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
