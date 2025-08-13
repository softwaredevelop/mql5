//+------------------------------------------------------------------+
//|                                       Stochastic_HeikenAshi.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.10" // Added selectable MA for Signal Line
#property description "Stochastic Oscillator on Heiken Ashi data with selectable MA for %D line."

// --- Standard and Custom Includes ---
#include <MyIncludes\HA_Tools.mqh>
#include <MovingAverages.mqh>

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
input int            InpKPeriod = 5;  // %K Period
input int            InpSlowing = 3;  // Slowing (initial %K smoothing)
input group          "Signal Line Settings"
input int            InpDPeriod = 3;  // %D Period (signal line smoothing)
input ENUM_MA_METHOD InpMAMethod = MODE_SMA; // MA Method for %D line

//--- Indicator Buffers ---
double    BufferHA_K[];     // Plotted buffer for the main %K line
double    BufferHA_D[];     // Plotted buffer for the signal %D line
double    BufferRawK[];     // Calculation buffer for raw %K before slowing
double    BufferHighest[];  // Calculation buffer for Highest HA_High in period
double    BufferLowest[];   // Calculation buffer for Lowest HA_Low in period

//--- Global Objects and Variables ---
int              ExtKPeriod, ExtDPeriod, ExtSlowing;
CHA_Calculator   g_ha_calculator; // Global instance of our Heiken Ashi calculator

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//| Called once when the indicator is first loaded.                  |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- Validate and store input periods
   ExtKPeriod = (InpKPeriod < 1) ? 1 : InpKPeriod;
   ExtDPeriod = (InpDPeriod < 1) ? 1 : InpDPeriod;
   ExtSlowing = (InpSlowing < 1) ? 1 : InpSlowing;

//--- Map the buffers to the indicator's internal memory
   SetIndexBuffer(0, BufferHA_K,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferHA_D,    INDICATOR_DATA);
   SetIndexBuffer(2, BufferRawK,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferHighest, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferLowest,  INDICATOR_CALCULATIONS);

//--- Set all buffers to work as regular arrays (non-timeseries)
   ArraySetAsSeries(BufferHA_K,    false);
   ArraySetAsSeries(BufferHA_D,    false);
   ArraySetAsSeries(BufferRawK,    false);
   ArraySetAsSeries(BufferHighest, false);
   ArraySetAsSeries(BufferLowest,  false);

//--- Set indicator display properties
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtKPeriod + ExtSlowing - 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtKPeriod + ExtSlowing + ExtDPeriod - 3);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_Stoch(%d,%d,%d)", ExtKPeriod, ExtDPeriod, ExtSlowing));
  }

//+------------------------------------------------------------------+
//| Stochastic Oscillator on Heiken Ashi calculation function.       |
//| Performs a full recalculation on every call for stability.       |
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
//--- Check if there is enough historical data for all calculations
   if(rates_total < ExtKPeriod + ExtSlowing + ExtDPeriod)
      return(0);

//--- STEP 1: Calculate Heiken Ashi bars using our toolkit
   if(!g_ha_calculator.Calculate(rates_total, 0, open, high, low, close))
      return(0);

//--- Main calculation loop, iterating from past to present
   for(int i = 0; i < rates_total; i++)
     {
      //--- STEP 2 & 3: Calculate Highest, Lowest, and Raw %K ---
      if(i >= ExtKPeriod - 1)
        {
         BufferHighest[i] = Highest(g_ha_calculator.ha_high, ExtKPeriod, i);
         BufferLowest[i]  = Lowest(g_ha_calculator.ha_low, ExtKPeriod, i);

         double range = BufferHighest[i] - BufferLowest[i];
         if(range > 0)
            BufferRawK[i] = (g_ha_calculator.ha_close[i] - BufferLowest[i]) / range * 100.0;
         else
            BufferRawK[i] = (i > 0) ? BufferRawK[i-1] : 50.0; // Avoid division by zero
        }
      else
        {
         // Initialize early bars to 0
         BufferHighest[i] = 0;
         BufferLowest[i] = 0;
         BufferRawK[i] = 0;
        }

      //--- STEP 4: Calculate Slow %K (Main Line) by smoothing Raw %K with SMA
      if(i >= ExtKPeriod + ExtSlowing - 2)
        {
         double sum = 0;
         for(int j = 0; j < ExtSlowing; j++)
            sum += BufferRawK[i-j];
         BufferHA_K[i] = sum / ExtSlowing;
        }
      else
        {
         BufferHA_K[i] = 0;
        }

      //--- STEP 5: Calculate %D (Signal Line) with user-selectable MA
      if(i >= ExtKPeriod + ExtSlowing + ExtDPeriod - 3)
        {
         switch(InpMAMethod)
           {
            case MODE_EMA:
               if(i == ExtKPeriod + ExtSlowing + ExtDPeriod - 3) // First EMA is an SMA
                  BufferHA_D[i] = SimpleMA(i, ExtDPeriod, BufferHA_K);
               else
                 {
                  double pr = 2.0 / (ExtDPeriod + 1.0);
                  BufferHA_D[i] = BufferHA_K[i] * pr + BufferHA_D[i-1] * (1.0 - pr);
                 }
               break;
            case MODE_SMMA:
               if(i == ExtKPeriod + ExtSlowing + ExtDPeriod - 3) // First SMMA is an SMA
                  BufferHA_D[i] = SimpleMA(i, ExtDPeriod, BufferHA_K);
               else
                  BufferHA_D[i] = (BufferHA_D[i-1] * (ExtDPeriod - 1) + BufferHA_K[i]) / ExtDPeriod;
               break;
            case MODE_LWMA:
               BufferHA_D[i] = LinearWeightedMA(i, ExtDPeriod, BufferHA_K);
               break;
            default: // MODE_SMA
              {
               double sum = 0;
               for(int j = 0; j < ExtDPeriod; j++)
                  sum += BufferHA_K[i-j];
               BufferHA_D[i] = sum / ExtDPeriod;
              }
            break;
           }
        }
      else
        {
         BufferHA_D[i] = 0;
        }
     }
//--- Return value of prev_calculated for next call
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Finds the highest value in a given period of an array.           |
//| INPUT:  array[]     - The data array to search in.               |
//|         period      - The number of elements to look back.       |
//|         current_pos - The starting position (index) to search from.|
//| RETURN: The highest value found in the specified range.          |
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
//| INPUT:  array[]     - The data array to search in.               |
//|         period      - The number of elements to look back.       |
//|         current_pos - The starting position (index) to search from.|
//| RETURN: The lowest value found in the specified range.           |
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
