//+------------------------------------------------------------------+
//|                                             FisherTransform.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored for stability and robust initialization
#property description "Fisher Transform Oscillator"

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
#property indicator_label1  "Fisher"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Trigger line
#property indicator_label2  "Trigger"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Input Parameters ---
input int InpLength = 9; // Length

//--- Indicator Buffers ---
double    BufferFisher[];
double    BufferTrigger[];
double    BufferValue[]; // Calculation buffer for the intermediate 'value'

//--- Global Variables ---
int       g_ExtLength;

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
   SetIndexBuffer(0, BufferFisher,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferTrigger, INDICATOR_DATA);
   SetIndexBuffer(2, BufferValue,   INDICATOR_CALCULATIONS);

//--- Set all buffers to non-timeseries for stable calculation
   ArraySetAsSeries(BufferFisher,  false);
   ArraySetAsSeries(BufferTrigger, false);
   ArraySetAsSeries(BufferValue,   false);

//--- Set indicator properties
   IndicatorSetInteger(INDICATOR_DIGITS, 4);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtLength);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtLength + 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Fisher(%d)", g_ExtLength));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Fisher Transform calculation function.                           |
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
   if(rates_total <= g_ExtLength)
      return(0);

//--- STEP 1: Create a buffer for HL2 price
   double hl2[];
   ArrayResize(hl2, rates_total);
   for(int i=0; i<rates_total; i++)
     {
      hl2[i] = (high[i] + low[i]) / 2.0;
     }

//--- STEP 2: Main calculation loop for Fisher Transform
   for(int i = 1; i < rates_total; i++)
     {
      if(i < g_ExtLength)
         continue;

      double high_ = Highest(hl2, g_ExtLength, i);
      double low_  = Lowest(hl2, g_ExtLength, i);

      double range = high_ - low_;
      if(range < _Point)
         range = _Point;

      double price_pos = (hl2[i] - low_) / range - 0.5;

      // Recursive smoothing for 'value'
      BufferValue[i] = 0.33 * 2 * price_pos + 0.67 * BufferValue[i-1];

      // Clamp the value to prevent log() errors
      if(BufferValue[i] > 0.999)
         BufferValue[i] = 0.999;
      if(BufferValue[i] < -0.999)
         BufferValue[i] = -0.999;

      // --- FIX: Robust initialization for the recursive Fisher calculation ---
      double log_val = 0.5 * MathLog((1 + BufferValue[i]) / (1 - BufferValue[i]));

      if(i == g_ExtLength) // First calculation (initialization)
        {
         BufferFisher[i] = log_val;
        }
      else // Subsequent calculations use the full recursive formula
        {
         BufferFisher[i] = log_val + 0.5 * BufferFisher[i-1];
        }

      // The trigger is the previous Fisher value
      BufferTrigger[i] = BufferFisher[i-1];
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
