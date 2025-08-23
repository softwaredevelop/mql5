//+------------------------------------------------------------------+
//|                                 StochasticFast_HeikinAshi.mq5    |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored for full recalculation and stability
#property description "Fast Stochastic Oscillator on Heikin Ashi data"

//--- Custom Toolkit Include ---
#include <MyIncludes\HeikinAshi_Tools.mqh>

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

//--- Intermediate Heikin Ashi Buffers ---
double    ExtHaOpenBuffer[];
double    ExtHaHighBuffer[];
double    ExtHaLowBuffer[];
double    ExtHaCloseBuffer[];

//--- Global Objects and Variables ---
int                       g_ExtKPeriod, g_ExtDPeriod;
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
   g_ExtKPeriod = (InpKPeriod < 1) ? 1 : InpKPeriod;
   g_ExtDPeriod = (InpDPeriod < 1) ? 1 : InpDPeriod;

//--- Map the buffers and set as non-timeseries
   SetIndexBuffer(0, BufferHA_K, INDICATOR_DATA);
   SetIndexBuffer(1, BufferHA_D, INDICATOR_DATA);
   ArraySetAsSeries(BufferHA_K, false);
   ArraySetAsSeries(BufferHA_D, false);

//--- Set indicator display properties
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtKPeriod - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtKPeriod + g_ExtDPeriod - 2);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_Fast_Stoch(%d,%d)", g_ExtKPeriod, g_ExtDPeriod));

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
   if(rates_total < g_ExtKPeriod + g_ExtDPeriod - 1)
      return(0);

//--- Resize intermediate buffers
   ArrayResize(ExtHaOpenBuffer, rates_total);
   ArrayResize(ExtHaHighBuffer, rates_total);
   ArrayResize(ExtHaLowBuffer, rates_total);
   ArrayResize(ExtHaCloseBuffer, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close,
                             ExtHaOpenBuffer, ExtHaHighBuffer, ExtHaLowBuffer, ExtHaCloseBuffer);

//--- STEP 2: Calculate Raw %K using Heiken Ashi data
   for(int i = g_ExtKPeriod - 1; i < rates_total; i++)
     {
      double highest_ha_high = Highest(ExtHaHighBuffer, g_ExtKPeriod, i);
      double lowest_ha_low   = Lowest(ExtHaLowBuffer, g_ExtKPeriod, i);

      double range = highest_ha_high - lowest_ha_low;
      if(range > 0)
         BufferHA_K[i] = (ExtHaCloseBuffer[i] - lowest_ha_low) / range * 100.0;
      else
         BufferHA_K[i] = (i > 0) ? BufferHA_K[i-1] : 50.0;
     }

//--- STEP 3: Calculate %D (Signal Line) as an SMA of %K
   int d_start_pos = g_ExtKPeriod + g_ExtDPeriod - 2;
   for(int i = d_start_pos; i < rates_total; i++)
     {
      double sum = 0;
      for(int j = 0; j < g_ExtDPeriod; j++)
        {
         sum += BufferHA_K[i-j];
        }
      BufferHA_D[i] = sum / g_ExtDPeriod;
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
