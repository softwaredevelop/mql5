//+------------------------------------------------------------------+
//|                                  StochasticFast_HeikenAshi.mq5   |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Fast Stochastic Oscillator on Heiken Ashi data"

//--- Custom Toolkit Include ---
#include <MyIncludes\HA_Tools.mqh>

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_buffers 2 // %K (Main) and %D (Signal)
#property indicator_plots   2
#property indicator_level1 20.0
#property indicator_level2 80.0
#property indicator_minimum 0.0
#property indicator_maximum 100.0

//--- Plot 1: %K line (Fast)
#property indicator_label1  "HA_%K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: %D line (Signal)
#property indicator_label2  "HA_%D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Input Parameters ---
input int InpKPeriod = 14; // %K Period (Stochastic period)
input int InpDPeriod = 3;  // %D Period (signal line smoothing)

//--- Indicator Buffers ---
double    BufferHA_K[]; // Plotted buffer for the main %K line
double    BufferHA_D[]; // Plotted buffer for the signal %D line

//--- Global Objects and Variables ---
int              ExtKPeriod, ExtDPeriod;
CHA_Calculator   g_ha_calculator;

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- Validate and store input periods
   ExtKPeriod = (InpKPeriod < 1) ? 1 : InpKPeriod;
   ExtDPeriod = (InpDPeriod < 1) ? 1 : InpDPeriod;

//--- Map the buffers and set as non-timeseries
   SetIndexBuffer(0, BufferHA_K, INDICATOR_DATA);
   SetIndexBuffer(1, BufferHA_D, INDICATOR_DATA);
   ArraySetAsSeries(BufferHA_K, false);
   ArraySetAsSeries(BufferHA_D, false);

//--- Set indicator display properties
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtKPeriod - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtKPeriod + ExtDPeriod - 2);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_Fast_Stoch(%d,%d)", ExtKPeriod, ExtDPeriod));
  }

//+------------------------------------------------------------------+
//| Fast Stochastic on Heiken Ashi calculation function.             |
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
   if(rates_total < ExtKPeriod + ExtDPeriod)
      return(0);

//--- STEP 1: Calculate Heiken Ashi bars using our toolkit
   if(!g_ha_calculator.Calculate(rates_total, 0, open, high, low, close))
      return(0);

//--- Main calculation loop, iterating from past to present
   for(int i = 0; i < rates_total; i++)
     {
      //--- STEP 2: Calculate Raw %K using Heiken Ashi data ---
      if(i >= ExtKPeriod - 1)
        {
         // Use HA High and HA Low from our calculator
         double highest_ha_high = Highest(g_ha_calculator.ha_high, ExtKPeriod, i);
         double lowest_ha_low   = Lowest(g_ha_calculator.ha_low, ExtKPeriod, i);

         double range = highest_ha_high - lowest_ha_low;
         if(range > 0)
            // Use HA Close from our calculator
            BufferHA_K[i] = (g_ha_calculator.ha_close[i] - lowest_ha_low) / range * 100.0;
         else
            BufferHA_K[i] = (i > 0) ? BufferHA_K[i-1] : 50.0;
        }
      else
        {
         BufferHA_K[i] = 0; // Not enough data yet
        }

      //--- STEP 3: Calculate %D (Signal Line) as an SMA of %K ---
      if(i >= ExtKPeriod + ExtDPeriod - 2)
        {
         double sum = 0;
         for(int j = 0; j < ExtDPeriod; j++)
           {
            sum += BufferHA_K[i-j];
           }
         BufferHA_D[i] = sum / ExtDPeriod;
        }
      else
        {
         BufferHA_D[i] = 0; // Not enough data yet
        }
     }
//--- Return value of prev_calculated for next call
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
