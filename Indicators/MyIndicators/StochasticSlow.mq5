//+------------------------------------------------------------------+
//|                                             StochasticSlow.mq5   |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Slow Stochastic Oscillator"

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_buffers 3 // %K, %D, and Raw %K for calculation
#property indicator_plots   2
#property indicator_level1 20.0
#property indicator_level2 80.0
#property indicator_minimum 0.0
#property indicator_maximum 100.0

//--- Plot 1: %K line (Slow)
#property indicator_label1  "%K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: %D line (Signal)
#property indicator_label2  "%D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Input Parameters ---
input int InpKPeriod = 5;  // %K Period
input int InpDPeriod = 3;  // %D Period (signal line smoothing)
input int InpSlowing = 3;  // Slowing (initial %K smoothing)

//--- Indicator Buffers ---
double    BufferK[];    // Plotted buffer for the main (Slow) %K line
double    BufferD[];    // Plotted buffer for the signal %D line
double    BufferRawK[]; // Calculation buffer for raw %K before slowing

//--- Global Variables ---
int       ExtKPeriod, ExtDPeriod, ExtSlowing;

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
   ExtSlowing = (InpSlowing < 1) ? 1 : InpSlowing;

//--- Map the buffers and set as non-timeseries
   SetIndexBuffer(0, BufferK,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferD,    INDICATOR_DATA);
   SetIndexBuffer(2, BufferRawK, INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferK,    false);
   ArraySetAsSeries(BufferD,    false);
   ArraySetAsSeries(BufferRawK, false);

//--- Set indicator display properties
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtKPeriod + ExtSlowing - 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtKPeriod + ExtSlowing + ExtDPeriod - 3);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Slow Stoch(%d,%d,%d)", ExtKPeriod, ExtDPeriod, ExtSlowing));
  }

//+------------------------------------------------------------------+
//| Slow Stochastic Oscillator calculation function.                 |
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
   if(rates_total < ExtKPeriod + ExtSlowing + ExtDPeriod)
      return(0);

//--- Main calculation loop, iterating from past to present
   for(int i = 0; i < rates_total; i++)
     {
      //--- STEP 1: Calculate Raw %K ---
      if(i >= ExtKPeriod - 1)
        {
         double highest_high = Highest(high, ExtKPeriod, i);
         double lowest_low   = Lowest(low, ExtKPeriod, i);

         double range = highest_high - lowest_low;
         if(range > 0)
            BufferRawK[i] = (close[i] - lowest_low) / range * 100.0;
         else
            BufferRawK[i] = (i > 0) ? BufferRawK[i-1] : 50.0;
        }
      else
        {
         BufferRawK[i] = 0;
        }

      //--- STEP 2: Calculate Slow %K (Main Line) by smoothing Raw %K ---
      if(i >= ExtKPeriod + ExtSlowing - 2)
        {
         double sum = 0;
         for(int j = 0; j < ExtSlowing; j++)
           {
            sum += BufferRawK[i-j];
           }
         BufferK[i] = sum / ExtSlowing;
        }
      else
        {
         BufferK[i] = 0;
        }

      //--- STEP 3: Calculate %D (Signal Line) by smoothing Slow %K ---
      if(i >= ExtKPeriod + ExtSlowing + ExtDPeriod - 3)
        {
         double sum = 0;
         for(int j = 0; j < ExtDPeriod; j++)
           {
            sum += BufferK[i-j];
           }
         BufferD[i] = sum / ExtDPeriod;
        }
      else
        {
         BufferD[i] = 0;
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
