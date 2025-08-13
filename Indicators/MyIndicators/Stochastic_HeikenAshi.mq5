//+------------------------------------------------------------------+
//|                                       Stochastic_HeikenAshi.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.01" // Corrected calculation loops to prevent array errors
#property description "Stochastic Oscillator on Heiken Ashi data"

#include <MyIncludes\HA_Tools.mqh>

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_buffers 5 // %K, %D, and 3 calculation buffers
#property indicator_plots   2
#property indicator_level1 20.0
#property indicator_level2 80.0
#property indicator_minimum 0.0
#property indicator_maximum 100.0

//--- Plot 1: %K line (Main)
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
input int InpKPeriod = 5;
input int InpDPeriod = 3;
input int InpSlowing = 3;

//--- Indicator Buffers ---
double    BufferHA_K[];
double    BufferHA_D[];
double    BufferRawK[];
double    BufferHighest[];
double    BufferLowest[];

//--- Global Objects and Variables ---
int              ExtKPeriod, ExtDPeriod, ExtSlowing;
CHA_Calculator   g_ha_calculator;

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
void OnInit()
  {
   ExtKPeriod = (InpKPeriod < 1) ? 1 : InpKPeriod;
   ExtDPeriod = (InpDPeriod < 1) ? 1 : InpDPeriod;
   ExtSlowing = (InpSlowing < 1) ? 1 : InpSlowing;

   SetIndexBuffer(0, BufferHA_K,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferHA_D,    INDICATOR_DATA);
   SetIndexBuffer(2, BufferRawK,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferHighest, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferLowest,  INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferHA_K,    false);
   ArraySetAsSeries(BufferHA_D,    false);
   ArraySetAsSeries(BufferRawK,    false);
   ArraySetAsSeries(BufferHighest, false);
   ArraySetAsSeries(BufferLowest,  false);

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtKPeriod + ExtSlowing - 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtKPeriod + ExtSlowing + ExtDPeriod - 3);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_Stoch(%d,%d,%d)", ExtKPeriod, ExtDPeriod, ExtSlowing));
  }

//+------------------------------------------------------------------+
//| Stochastic Oscillator on Heiken Ashi calculation function.       |
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
   if(rates_total < ExtKPeriod + ExtSlowing + ExtDPeriod)
      return(0);

//--- STEP 1: Calculate Heiken Ashi bars
   if(!g_ha_calculator.Calculate(rates_total, 0, open, high, low, close))
      return(0);

//--- STEP 2, 3, 4, 5: Main calculation loop from past to present
   for(int i = 0; i < rates_total; i++)
     {
      // --- Calculate Highest and Lowest for Raw %K ---
      if(i >= ExtKPeriod - 1)
        {
         BufferHighest[i] = Highest(g_ha_calculator.ha_high, ExtKPeriod, i);
         BufferLowest[i]  = Lowest(g_ha_calculator.ha_low, ExtKPeriod, i);

         double range = BufferHighest[i] - BufferLowest[i];
         if(range > 0)
            BufferRawK[i] = (g_ha_calculator.ha_close[i] - BufferLowest[i]) / range * 100.0;
         else
            BufferRawK[i] = (i > 0) ? BufferRawK[i-1] : 50.0;
        }
      else
        {
         // Not enough data yet for these buffers
         BufferHighest[i] = 0;
         BufferLowest[i] = 0;
         BufferRawK[i] = 0;
        }

      // --- Calculate Slow %K (Main Line) ---
      if(i >= ExtKPeriod + ExtSlowing - 2)
        {
         double sum = 0;
         for(int j = 0; j < ExtSlowing; j++)
           {
            sum += BufferRawK[i-j];
           }
         BufferHA_K[i] = sum / ExtSlowing;
        }
      else
        {
         BufferHA_K[i] = 0; // Not enough data yet
        }

      // --- Calculate %D (Signal Line) ---
      if(i >= ExtKPeriod + ExtSlowing + ExtDPeriod - 3)
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
   return(rates_total);
  }

// ... (Highest and Lowest functions remain the same) ...
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
//|                                                                  |
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
