//+------------------------------------------------------------------+
//|                                    StochasticSlow_HeikinAshi.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.01" // Harmonized input parameter names
#property description "Slow Stochastic Oscillator on Heikin Ashi data"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_buffers 3 // %K, %D, and Raw %K for calculation
#property indicator_plots   2
#property indicator_level1 20.0
#property indicator_level2 80.0
#property indicator_minimum 0.0
#property indicator_maximum 100.0

//--- Plot 1: %K line (Slow)
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
input int InpKPeriod       = 5;
input int InpSlowingPeriod = 3;
input int InpDPeriod       = 3;

//--- Indicator Buffers ---
double    BufferHA_K[];
double    BufferHA_D[];
double    BufferRawK[];

//--- Global Objects and Variables ---
int                       g_ExtKPeriod, g_ExtDPeriod, g_ExtSlowingPeriod;
CHeikinAshi_Calculator   *g_ha_calculator;

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtKPeriod       = (InpKPeriod < 1) ? 1 : InpKPeriod;
   g_ExtDPeriod       = (InpDPeriod < 1) ? 1 : InpDPeriod;
   g_ExtSlowingPeriod = (InpSlowingPeriod < 1) ? 1 : InpSlowingPeriod;

   SetIndexBuffer(0, BufferHA_K,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferHA_D,    INDICATOR_DATA);
   SetIndexBuffer(2, BufferRawK,    INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferHA_K,    false);
   ArraySetAsSeries(BufferHA_D,    false);
   ArraySetAsSeries(BufferRawK,    false);

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtKPeriod + g_ExtSlowingPeriod - 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtKPeriod + g_ExtSlowingPeriod + g_ExtDPeriod - 3);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_Slow_Stoch(%d,%d,%d)", g_ExtKPeriod, g_ExtSlowingPeriod, g_ExtDPeriod));

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
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
     {
      delete g_ha_calculator;
      g_ha_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Slow Stochastic on Heikin Ashi calculation function.             |
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
   int start_pos = g_ExtKPeriod + g_ExtSlowingPeriod + g_ExtDPeriod - 2;
   if(rates_total <= start_pos)
      return(0);

//--- Intermediate Heikin Ashi Buffers
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- STEP 2: Calculate Raw %K (Fast %K) using Heikin Ashi data
   for(int i = g_ExtKPeriod - 1; i < rates_total; i++)
     {
      double highest_ha_high = Highest(ha_high, g_ExtKPeriod, i);
      double lowest_ha_low   = Lowest(ha_low, g_ExtKPeriod, i);
      double range = highest_ha_high - lowest_ha_low;
      if(range > 0)
         BufferRawK[i] = (ha_close[i] - lowest_ha_low) / range * 100.0;
      else
         BufferRawK[i] = (i > 0) ? BufferRawK[i-1] : 50.0;
     }

//--- STEP 3: Calculate Slow %K (Main Line) by smoothing Raw %K
   int k_slow_start_pos = g_ExtKPeriod + g_ExtSlowingPeriod - 2;
   for(int i = k_slow_start_pos; i < rates_total; i++)
     {
      double sum = 0;
      for(int j = 0; j < g_ExtSlowingPeriod; j++)
        {
         sum += BufferRawK[i-j];
        }
      BufferHA_K[i] = sum / g_ExtSlowingPeriod;
     }

//--- STEP 4: Calculate %D (Signal Line) by smoothing Slow %K
   int d_start_pos = g_ExtKPeriod + g_ExtSlowingPeriod + g_ExtDPeriod - 3;
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
