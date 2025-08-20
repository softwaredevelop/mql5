//+------------------------------------------------------------------+
//|                                     StochRSI_Slow_HeikenAshi.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Slow Stochastic on a Heiken Ashi based RSI"

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

//--- Global Variables ---
int       ExtLengthRSI, ExtLengthStoch, ExtSlowing, ExtSmoothD;
int       handle_ha_rsi; // Handle for our custom RSI_HeikenAshi indicator

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
void OnInit()
  {
   ExtLengthRSI   = (InpLengthRSI < 1) ? 1 : InpLengthRSI;
   ExtLengthStoch = (InpLengthStoch < 1) ? 1 : InpLengthStoch;
   ExtSlowing     = (InpSlowing < 1) ? 1 : InpSlowing;
   ExtSmoothD     = (InpSmoothD < 1) ? 1 : InpSmoothD;

   SetIndexBuffer(0, BufferK,         INDICATOR_DATA);
   SetIndexBuffer(1, BufferD,         INDICATOR_DATA);
   SetIndexBuffer(2, BufferHA_RSI,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferRawStochK, INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferK,         false);
   ArraySetAsSeries(BufferD,         false);
   ArraySetAsSeries(BufferHA_RSI,    false);
   ArraySetAsSeries(BufferRawStochK, false);

//--- Create a handle to our custom RSI_HeikenAshi indicator
   string indicator_path = "MyIndicators\\RSI_HeikenAshi";
   handle_ha_rsi = iCustom(_Symbol, _Period, indicator_path,
                           ExtLengthRSI, // Pass RSI Period
                           14,           // Pass default MA Period
                           MODE_SMA      // Pass default MA Method
                          );
   if(handle_ha_rsi == INVALID_HANDLE)
      Print("Error creating iCustom handle for RSI_HeikenAshi.");

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtLengthRSI + ExtLengthStoch + ExtSlowing - 3);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtLengthRSI + ExtLengthStoch + ExtSlowing + ExtSmoothD - 4);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_StochRSI_Slow(%d,%d,%d,%d)", ExtLengthRSI, ExtLengthStoch, ExtSlowing, ExtSmoothD));
  }

//+------------------------------------------------------------------+
//| Slow StochRSI on Heiken Ashi calculation function.               |
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
   if(rates_total < ExtLengthRSI + ExtLengthStoch)
      return(0);

//--- STEP 1: Get Heiken Ashi RSI values from our custom indicator
   if(BarsCalculated(handle_ha_rsi) < rates_total)
      return(0);
// We need the raw HA_RSI line, which is in buffer #1 of the RSI_HeikenAshi indicator
   if(CopyBuffer(handle_ha_rsi, 1, 0, rates_total, BufferHA_RSI) <= 0)
      return(0);

//--- Main calculation loop
   for(int i = 0; i < rates_total; i++)
     {
      //--- STEP 2: Calculate Raw Stochastic %K on the HA_RSI buffer ---
      if(i >= ExtLengthRSI + ExtLengthStoch - 2)
        {
         double highest_ha_rsi = Highest(BufferHA_RSI, ExtLengthStoch, i);
         double lowest_ha_rsi  = Lowest(BufferHA_RSI, ExtLengthStoch, i);

         double range = highest_ha_rsi - lowest_ha_rsi;
         if(range > 0.00001)
            BufferRawStochK[i] = (BufferHA_RSI[i] - lowest_ha_rsi) / range * 100.0;
         else
            BufferRawStochK[i] = (i > 0) ? BufferRawStochK[i-1] : 50.0;
        }
      else
        {
         BufferRawStochK[i] = 0;
        }

      //--- STEP 3: Calculate Slow %K (Main Line) by smoothing Raw %K ---
      if(i >= ExtLengthRSI + ExtLengthStoch + ExtSlowing - 3)
        {
         double sum = 0;
         for(int j = 0; j < ExtSlowing; j++)
           {
            sum += BufferRawStochK[i-j];
           }
         BufferK[i] = sum / ExtSlowing;
        }
      else
        {
         BufferK[i] = 0;
        }

      //--- STEP 4: Calculate %D (Signal Line) by smoothing Slow %K ---
      if(i >= ExtLengthRSI + ExtLengthStoch + ExtSlowing + ExtSmoothD - 4)
        {
         double sum = 0;
         for(int j = 0; j < ExtSmoothD; j++)
           {
            sum += BufferK[i-j];
           }
         BufferD[i] = sum / ExtSmoothD;
        }
      else
        {
         BufferD[i] = 0;
        }
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
