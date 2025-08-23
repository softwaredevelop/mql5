//+------------------------------------------------------------------+
//|                                                          WPR.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored for stability and clarity
#property description "Larry Williams' Percent Range"

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
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: WPR line
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_label1  "WPR"

//--- Input Parameters ---
input int InpWPRPeriod = 14; // Period for WPR calculation

//--- Indicator Buffers ---
double    BufferWPR[];

//--- Global Variables ---
int       g_ExtWPRPeriod;

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtWPRPeriod = (InpWPRPeriod < 1) ? 1 : InpWPRPeriod;

   SetIndexBuffer(0, BufferWPR, INDICATOR_DATA);
   ArraySetAsSeries(BufferWPR, false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtWPRPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("WPR(%d)", g_ExtWPRPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Williams’ Percent Range calculation function.                    |
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
   if(rates_total < g_ExtWPRPeriod)
      return(0);

//--- Main calculation loop
   for(int i = g_ExtWPRPeriod - 1; i < rates_total; i++)
     {
      double highest_high = Highest(high, g_ExtWPRPeriod, i);
      double lowest_low   = Lowest(low, g_ExtWPRPeriod, i);
      double range = highest_high - lowest_low;

      if(range > 0)
         BufferWPR[i] = -100.0 * (highest_high - close[i]) / range;
      else
         BufferWPR[i] = (i > 0) ? BufferWPR[i-1] : -50.0; // Avoid division by zero
     }

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
      if(res < array[current_pos - i])
         res = array[current_pos - i];
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
      if(res > array[current_pos - i])
         res = array[current_pos - i];
     }
   return(res);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
