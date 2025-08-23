//+------------------------------------------------------------------+
//|                                             StochasticFast.mq5   |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored for stability and clarity
#property description "Fast Stochastic Oscillator"

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_buffers 2 // %K (Main) and %D (Signal)
#property indicator_plots   2
#property indicator_level1 20.0
#property indicator_level2 80.0
#property indicator_minimum 0.0
#property indicator_maximum 100.0

//--- Plot 1: %K line (Fast)
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
input int InpKPeriod = 14; // %K Period (Stochastic period)
input int InpDPeriod = 3;  // %D Period (signal line smoothing)

//--- Indicator Buffers ---
double    BufferK[]; // Plotted buffer for the main %K line
double    BufferD[]; // Plotted buffer for the signal %D line

//--- Global Variables ---
int       g_ExtKPeriod, g_ExtDPeriod;

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate and store input periods
   g_ExtKPeriod = (InpKPeriod < 1) ? 1 : InpKPeriod;
   g_ExtDPeriod = (InpDPeriod < 1) ? 1 : InpDPeriod;

//--- Map the buffers and set as non-timeseries
   SetIndexBuffer(0, BufferK, INDICATOR_DATA);
   SetIndexBuffer(1, BufferD, INDICATOR_DATA);
   ArraySetAsSeries(BufferK, false);
   ArraySetAsSeries(BufferD, false);

//--- Set indicator display properties
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtKPeriod - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtKPeriod + g_ExtDPeriod - 2);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Fast Stoch(%d,%d)", g_ExtKPeriod, g_ExtDPeriod));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Fast Stochastic Oscillator calculation function.                 |
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
   int start_pos = g_ExtKPeriod + g_ExtDPeriod - 1;
   if(rates_total <= start_pos)
      return(0);

//--- STEP 1: Calculate %K (Fast %K)
   for(int i = g_ExtKPeriod - 1; i < rates_total; i++)
     {
      double highest_high = Highest(high, g_ExtKPeriod, i);
      double lowest_low   = Lowest(low, g_ExtKPeriod, i);

      double range = highest_high - lowest_low;
      if(range > 0)
         BufferK[i] = (close[i] - lowest_low) / range * 100.0;
      else
         BufferK[i] = (i > 0) ? BufferK[i-1] : 50.0;
     }

//--- STEP 2: Calculate %D (Signal Line) as an SMA of %K
   int d_start_pos = g_ExtKPeriod + g_ExtDPeriod - 2;
   for(int i = d_start_pos; i < rates_total; i++)
     {
      double sum = 0;
      for(int j = 0; j < g_ExtDPeriod; j++)
        {
         sum += BufferK[i-j];
        }
      BufferD[i] = sum / g_ExtDPeriod;
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
