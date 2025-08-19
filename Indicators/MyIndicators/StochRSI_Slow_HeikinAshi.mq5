//+------------------------------------------------------------------+
//|                                    StochRSI_Slow_HeikinAshi.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored to be self-contained, no iCustom
#property description "Slow Stochastic on a Heikin Ashi based RSI"

//--- Custom Toolkit Include ---
#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_buffers 4 // %K, %D, RawK, and HA_RSI buffer
#property indicator_plots   2
#property indicator_level1 20.0
#property indicator_level2 80.0
#property indicator_minimum -10.0
#property indicator_maximum 110.0

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
input int InpLengthRSI   = 14; // RSI Length
input int InpLengthStoch = 14; // Stochastic %K Period
input int InpSlowing     = 3;  // Slowing Period
input int InpSmoothD     = 3;  // %D Smoothing Period

//--- Indicator Buffers ---
double    BufferK[];
double    BufferD[];
double    BufferHA_RSI[];
double    BufferRawStochK[];

//--- Global Objects and Variables ---
int                           g_ExtLengthRSI, g_ExtLengthStoch, g_ExtSlowing, g_ExtSmoothD;
CHeikinAshi_RSI_Calculator   *g_ha_rsi_calculator; // Pointer to our HA_RSI calculator

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtLengthRSI   = (InpLengthRSI < 1) ? 1 : InpLengthRSI;
   g_ExtLengthStoch = (InpLengthStoch < 1) ? 1 : InpLengthStoch;
   g_ExtSlowing     = (InpSlowing < 1) ? 1 : InpSlowing;
   g_ExtSmoothD     = (InpSmoothD < 1) ? 1 : InpSmoothD;

   SetIndexBuffer(0, BufferK,         INDICATOR_DATA);
   SetIndexBuffer(1, BufferD,         INDICATOR_DATA);
   SetIndexBuffer(2, BufferHA_RSI,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferRawStochK, INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferK,         false);
   ArraySetAsSeries(BufferD,         false);
   ArraySetAsSeries(BufferHA_RSI,    false);
   ArraySetAsSeries(BufferRawStochK, false);

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtLengthRSI + g_ExtLengthStoch + g_ExtSlowing - 3);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtLengthRSI + g_ExtLengthStoch + g_ExtSlowing + g_ExtSmoothD - 4);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_StochRSI_Slow(%d,%d,%d,%d)", g_ExtLengthRSI, g_ExtLengthStoch, g_ExtSlowing, g_ExtSmoothD));

//--- Create the calculator instance
   g_ha_rsi_calculator = new CHeikinAshi_RSI_Calculator();
   if(CheckPointer(g_ha_rsi_calculator) == POINTER_INVALID)
     {
      Print("Error creating CHeikinAshi_RSI_Calculator object");
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
   if(CheckPointer(g_ha_rsi_calculator) != POINTER_INVALID)
     {
      delete g_ha_rsi_calculator;
      g_ha_rsi_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Slow StochRSI on Heikin Ashi calculation function.               |
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
   int start_pos = g_ExtLengthRSI + g_ExtLengthStoch + g_ExtSlowing + g_ExtSmoothD - 3;
   if(rates_total <= start_pos)
      return(0);

//--- STEP 1: Calculate Heikin Ashi RSI values using our toolkit
   if(!g_ha_rsi_calculator.Calculate(rates_total, g_ExtLengthRSI, open, high, low, close, BufferHA_RSI))
     {
      Print("Heikin Ashi RSI calculation failed.");
      return(0);
     }

//--- STEP 2: Calculate Raw Stochastic %K on the HA_RSI buffer
   int raw_k_start_pos = g_ExtLengthRSI + g_ExtLengthStoch - 2;
   for(int i = raw_k_start_pos; i < rates_total; i++)
     {
      double highest_ha_rsi = Highest(BufferHA_RSI, g_ExtLengthStoch, i);
      double lowest_ha_rsi  = Lowest(BufferHA_RSI, g_ExtLengthStoch, i);

      double range = highest_ha_rsi - lowest_ha_rsi;
      if(range > 0.00001)
         BufferRawStochK[i] = (BufferHA_RSI[i] - lowest_ha_rsi) / range * 100.0;
      else
         BufferRawStochK[i] = (i > 0) ? BufferRawStochK[i-1] : 50.0;
     }

//--- STEP 3: Calculate Slow %K (Main Line) by smoothing Raw %K
   int k_slow_start_pos = g_ExtLengthRSI + g_ExtLengthStoch + g_ExtSlowing - 3;
   for(int i = k_slow_start_pos; i < rates_total; i++)
     {
      double sum = 0;
      for(int j = 0; j < g_ExtSlowing; j++)
        {
         sum += BufferRawStochK[i-j];
        }
      BufferK[i] = sum / g_ExtSlowing;
     }

//--- STEP 4: Calculate %D (Signal Line) by smoothing Slow %K
   int d_start_pos = g_ExtLengthRSI + g_ExtLengthStoch + g_ExtSlowing + g_ExtSmoothD - 4;
   for(int i = d_start_pos; i < rates_total; i++)
     {
      double sum = 0;
      for(int j = 0; j < g_ExtSmoothD; j++)
        {
         sum += BufferK[i-j];
        }
      BufferD[i] = sum / g_ExtSmoothD;
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
