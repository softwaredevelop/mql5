//+------------------------------------------------------------------+
//|                                    FisherTransform_HeikinAshi.mq5|
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored for full recalculation and stability
#property description "Fisher Transform Oscillator on Heikin Ashi data"

//--- Custom Toolkit Include ---
#include <MyIncludes\HeikinAshi_Tools.mqh>

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

//--- Intermediate Heikin Ashi Buffers ---
double    ExtHaOpenBuffer[];
double    ExtHaHighBuffer[];
double    ExtHaLowBuffer[];
double    ExtHaCloseBuffer[];

//--- Global Objects and Variables ---
int                       g_ExtLength;
CHeikinAshi_Calculator   *g_ha_calculator; // Pointer to our Heikin Ashi calculator

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate and store input
   g_ExtLength = (InpLength < 1) ? 1 : InpLength;

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
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtLength);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtLength + 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_Fisher(%d)", g_ExtLength));

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
//--- Free the calculator object to prevent memory leaks
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
     {
      delete g_ha_calculator;
      g_ha_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Fisher Transform on Heikin Ashi calculation function.            |
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
   if(rates_total <= g_ExtLength)
      return(0);

//--- Resize intermediate buffers
   ArrayResize(ExtHaOpenBuffer, rates_total);
   ArrayResize(ExtHaHighBuffer, rates_total);
   ArrayResize(ExtHaLowBuffer, rates_total);
   ArrayResize(ExtHaCloseBuffer, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close,
                             ExtHaOpenBuffer, ExtHaHighBuffer, ExtHaLowBuffer, ExtHaCloseBuffer);

//--- STEP 2: Create a buffer for Heikin Ashi HL2 price
   double ha_hl2[];
   ArrayResize(ha_hl2, rates_total);
   for(int i=0; i<rates_total; i++)
     {
      ha_hl2[i] = (ExtHaHighBuffer[i] + ExtHaLowBuffer[i]) / 2.0;
     }

//--- STEP 3: Main calculation loop for Fisher Transform
   for(int i = 1; i < rates_total; i++)
     {
      // Skip bars that don't have enough history for the period
      if(i < g_ExtLength)
         continue;

      // Get Highest/Lowest of Heikin Ashi HL2
      double high_ = Highest(ha_hl2, g_ExtLength, i);
      double low_  = Lowest(ha_hl2, g_ExtLength, i);

      double range = high_ - low_;
      if(range < _Point)
         range = _Point;

      // Calculate the intermediate 'value'
      double price_pos = (ha_hl2[i] - low_) / range - 0.5;
      BufferValue[i] = 0.33 * 2 * price_pos + 0.67 * BufferValue[i-1];

      // Clamp the value to avoid issues with MathLog
      if(BufferValue[i] > 0.999)
         BufferValue[i] = 0.999;
      if(BufferValue[i] < -0.999)
         BufferValue[i] = -0.999;

      // --- FIX: Robust initialization for the recursive calculation ---
      double log_val = 0.5 * MathLog((1 + BufferValue[i]) / (1 - BufferValue[i]));

      if(i == g_ExtLength) // First calculation (initialization)
        {
         // For the very first value, we don't use the recursive part
         BufferHA_Fisher[i] = log_val;
        }
      else // Subsequent calculations use the full recursive formula
        {
         BufferHA_Fisher[i] = log_val + 0.5 * BufferHA_Fisher[i-1];
        }

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
