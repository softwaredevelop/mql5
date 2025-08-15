//+------------------------------------------------------------------+
//|                                     FisherTransform_HeikenAshi.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Fisher Transform Oscillator on Heiken Ashi data"

//--- Custom Toolkit Include ---
#include <MyIncludes\HA_Tools.mqh>

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_level1  1.5
#property indicator_level2  0.75
#property indicator_level3  0.0
#property indicator_level4 -0.75
#property indicator_level5 -1.5
#property indicator_levelstyle STYLE_DOT

//--- Buffers and Plots ---
#property indicator_buffers 3 // Fisher, Trigger, and 1 calculation buffer
#property indicator_plots   2

//--- Plot 1: Fisher line
#property indicator_label1  "HA_Fisher"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Trigger line
#property indicator_label2  "HA_Trigger"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Input Parameters ---
input int InpLength = 9; // Length

//--- Indicator Buffers ---
double    BufferHA_Fisher[];
double    BufferHA_Trigger[];
double    BufferValue[]; // Calculation buffer for the intermediate 'value'

//--- Global Objects and Variables ---
int              ExtLength;
CHA_Calculator   g_ha_calculator;

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- Validate and store input
   ExtLength = (InpLength < 1) ? 1 : InpLength;

//--- Map the buffers
   SetIndexBuffer(0, BufferHA_Fisher,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferHA_Trigger, INDICATOR_DATA);
   SetIndexBuffer(2, BufferValue,      INDICATOR_CALCULATIONS);

//--- Set all buffers to non-timeseries for stable calculation
   ArraySetAsSeries(BufferHA_Fisher,  false);
   ArraySetAsSeries(BufferHA_Trigger, false);
   ArraySetAsSeries(BufferValue,      false);

//--- Set indicator properties
   IndicatorSetInteger(INDICATOR_DIGITS, 4);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtLength);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtLength + 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_Fisher(%d)", ExtLength));
  }

//+------------------------------------------------------------------+
//| Fisher Transform on Heiken Ashi calculation function.            |
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
//--- Check for enough data
   if(rates_total < ExtLength)
      return(0);

//--- STEP 1: Calculate Heiken Ashi bars using our toolkit
   if(!g_ha_calculator.Calculate(rates_total, 0, open, high, low, close))
      return(0);

//--- STEP 2: Create a buffer for Heiken Ashi HL2 price
   double ha_hl2[];
   ArrayResize(ha_hl2, rates_total);
   for(int i=0; i<rates_total; i++)
     {
      ha_hl2[i] = (g_ha_calculator.ha_high[i] + g_ha_calculator.ha_low[i]) / 2.0;
     }

//--- STEP 3: Main calculation loop
   for(int i = 1; i < rates_total; i++)
     {
      if(i < ExtLength)
        {
         BufferValue[i] = 0;
         BufferHA_Fisher[i] = 0;
         continue;
        }

      // Get Highest/Lowest of Heiken Ashi HL2
      double high_ = Highest(ha_hl2, ExtLength, i);
      double low_  = Lowest(ha_hl2, ExtLength, i);

      double range = high_ - low_;
      if(range < _Point)
         range = _Point;

      // Calculate the intermediate 'value'
      double price_pos = 0;
      if(range > 0)
         price_pos = (ha_hl2[i] - low_) / range - 0.5;

      BufferValue[i] = 0.33 * 2 * price_pos + 0.67 * BufferValue[i-1];

      if(BufferValue[i] > 0.999)
         BufferValue[i] = 0.999;
      if(BufferValue[i] < -0.999)
         BufferValue[i] = -0.999;

      // Calculate the Fisher Transform value
      double log_val = 0.5 * MathLog((1 + BufferValue[i]) / (1 - BufferValue[i]));
      BufferHA_Fisher[i] = log_val + 0.5 * BufferHA_Fisher[i-1];

      // The trigger is the previous Fisher value
      BufferHA_Trigger[i] = BufferHA_Fisher[i-1];
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
