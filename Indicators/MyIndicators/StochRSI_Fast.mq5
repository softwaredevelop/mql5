//+------------------------------------------------------------------+
//|                                                StochRSI_Fast.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Fast Stochastic RSI Oscillator"

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_buffers 3 // %K, %D, and RSI calculation buffer
#property indicator_plots   2
#property indicator_level1 20.0
#property indicator_level2 80.0
#property indicator_minimum -10.0
#property indicator_maximum 110.0

//--- Plot 1: %K line
#property indicator_label1  "%K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: %D line
#property indicator_label2  "%D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Input Parameters ---
input int InpLengthRSI   = 14; // RSI Length
input int InpLengthStoch = 14; // Stochastic Length (%K Period)
input int InpSmoothD     = 3;  // %D Smoothing (Signal Line)
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // RSI Source Price

//--- Indicator Buffers ---
double    BufferK[];
double    BufferD[];
double    BufferRSI[];

//--- Global Variables ---
int       ExtLengthRSI, ExtLengthStoch, ExtSmoothD;
int       handle_rsi;

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
   ExtSmoothD     = (InpSmoothD < 1) ? 1 : InpSmoothD;

   SetIndexBuffer(0, BufferK,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferD,   INDICATOR_DATA);
   SetIndexBuffer(2, BufferRSI, INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferK,   false);
   ArraySetAsSeries(BufferD,   false);
   ArraySetAsSeries(BufferRSI, false);

   handle_rsi = iRSI(_Symbol, _Period, ExtLengthRSI, InpAppliedPrice);
   if(handle_rsi == INVALID_HANDLE)
      Print("Error creating iRSI handle.");

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtLengthRSI + ExtLengthStoch - 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtLengthRSI + ExtLengthStoch + ExtSmoothD - 3);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Fast StochRSI(%d,%d,%d)", ExtLengthRSI, ExtLengthStoch, ExtSmoothD));
  }

//+------------------------------------------------------------------+
//| Fast Stochastic RSI calculation function.                        |
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

//--- STEP 1: Get RSI values from the standard indicator
   if(BarsCalculated(handle_rsi) < rates_total)
      return(0);
   if(CopyBuffer(handle_rsi, 0, 0, rates_total, BufferRSI) <= 0)
      return(0);

//--- Main calculation loop
   for(int i = 0; i < rates_total; i++)
     {
      //--- STEP 2: Calculate Fast %K on the RSI buffer ---
      if(i >= ExtLengthRSI + ExtLengthStoch - 2)
        {
         // Since RSI is both high, low, and close, we use it for all
         double highest_rsi = Highest(BufferRSI, ExtLengthStoch, i);
         double lowest_rsi  = Lowest(BufferRSI, ExtLengthStoch, i);

         double range = highest_rsi - lowest_rsi;
         if(range > 0.00001) // Use a small tolerance for floating point numbers
            BufferK[i] = (BufferRSI[i] - lowest_rsi) / range * 100.0;
         else
            BufferK[i] = (i > 0) ? BufferK[i-1] : 50.0;
        }
      else
        {
         BufferK[i] = 0;
        }

      //--- STEP 3: Calculate %D (Signal Line) as an SMA of %K ---
      if(i >= ExtLengthRSI + ExtLengthStoch + ExtSmoothD - 3)
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
