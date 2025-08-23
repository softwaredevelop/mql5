//+------------------------------------------------------------------+
//|                                           WPR_HeikinAshi.mq5     |
//|            Copyright 2025, xxxxxxxx (Based on MetaQuotes WPR)    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2025, xxxxxxxx"
#property link        ""
#property version     "3.00" // Refactored for stability and new calculator
#property description "Larry Williams' Percent Range based on Heikin Ashi candles"

//--- Custom Toolkit Include ---
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
#property indicator_buffers    1 // Only one buffer is needed for the WPR line
#property indicator_plots      1

//--- Plot 1: WPR line
#property indicator_type1      DRAW_LINE
#property indicator_color1     clrDodgerBlue
#property indicator_label1     "HA_WPR"

//--- Input Parameters ---
input int InpWPRPeriod=14; // Period for WPR calculation

//--- Indicator Buffers ---
double    BufferHA_WPR[];      // The final WPR values for plotting

//--- Intermediate Heikin Ashi Buffers ---
double    ExtHaOpenBuffer[];
double    ExtHaHighBuffer[];
double    ExtHaLowBuffer[];
double    ExtHaCloseBuffer[];

//--- Global Objects and Variables ---
int                       g_ExtPeriodWPR;
CHeikinAshi_Calculator   *g_ha_calculator; // Pointer to our Heikin Ashi calculator

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate and store the WPR period
   g_ExtPeriodWPR = (InpWPRPeriod < 1) ? 1 : InpWPRPeriod;

//--- Map the buffer to the indicator's internal memory
   SetIndexBuffer(0, BufferHA_WPR, INDICATOR_DATA);
//--- Set buffer as non-timeseries for stable calculation
   ArraySetAsSeries(BufferHA_WPR, false);

//--- Set indicator properties
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtPeriodWPR - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_WPR(%d)", g_ExtPeriodWPR));
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
//| Williams’ Percent Range on Heikin Ashi.                          |
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
   if(rates_total < g_ExtPeriodWPR)
      return(0);

//--- Resize intermediate buffers to match the available bars
   ArrayResize(ExtHaOpenBuffer, rates_total);
   ArrayResize(ExtHaHighBuffer, rates_total);
   ArrayResize(ExtHaLowBuffer, rates_total);
   ArrayResize(ExtHaCloseBuffer, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars using our toolkit (full recalculation)
   g_ha_calculator.Calculate(rates_total, open, high, low, close,
                             ExtHaOpenBuffer, ExtHaHighBuffer, ExtHaLowBuffer, ExtHaCloseBuffer);

//--- STEP 2: Calculate WPR based on the Heikin Ashi results
// Start from the first bar that has enough preceding data for the WPR period
   for(int i = g_ExtPeriodWPR - 1; i < rates_total; i++)
     {
      // Find the highest HA_High and lowest HA_Low over the WPR period
      double max_ha_high = Highest(ExtHaHighBuffer, g_ExtPeriodWPR, i);
      double min_ha_low  = Lowest(ExtHaLowBuffer, g_ExtPeriodWPR, i);

      // Calculate WPR using the current HA_Close
      if(max_ha_high != min_ha_low)
         BufferHA_WPR[i] = - (max_ha_high - ExtHaCloseBuffer[i]) * 100.0 / (max_ha_high - min_ha_low);
      else
         // If max high equals min low, avoid division by zero
         BufferHA_WPR[i] = (i > 0) ? BufferHA_WPR[i-1] : -50.0;
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
//--- Loop backwards from the current position for 'period' bars
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break; // Stop if we go out of bounds

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
//--- Loop backwards from the current position for 'period' bars
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break; // Stop if we go out of bounds

      if(res > array[index])
         res = array[index];
     }
   return(res);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
