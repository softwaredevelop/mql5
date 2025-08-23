//+------------------------------------------------------------------+
//|                                               StochRSI_Fast.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored for stability and clarity
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
int       g_ExtLengthRSI, g_ExtLengthStoch, g_ExtSmoothD;
int       g_handle_rsi;

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
   g_ExtSmoothD     = (InpSmoothD < 1) ? 1 : InpSmoothD;

   SetIndexBuffer(0, BufferK,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferD,   INDICATOR_DATA);
   SetIndexBuffer(2, BufferRSI, INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferK,   false);
   ArraySetAsSeries(BufferD,   false);
   ArraySetAsSeries(BufferRSI, false);

   g_handle_rsi = iRSI(_Symbol, _Period, g_ExtLengthRSI, InpAppliedPrice);
   if(g_handle_rsi == INVALID_HANDLE)
     {
      Print("Error creating iRSI handle.");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtLengthRSI + g_ExtLengthStoch - 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtLengthRSI + g_ExtLengthStoch + g_ExtSmoothD - 3);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Fast StochRSI(%d,%d,%d)", g_ExtLengthRSI, g_ExtLengthStoch, g_ExtSmoothD));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Release the indicator handle
   IndicatorRelease(g_handle_rsi);
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
   int start_pos = g_ExtLengthRSI + g_ExtLengthStoch + g_ExtSmoothD - 2;
   if(rates_total <= start_pos)
      return(0);

//--- STEP 1: Get RSI values from the standard indicator
   if(CopyBuffer(g_handle_rsi, 0, 0, rates_total, BufferRSI) < rates_total)
     {
      Print("Error copying iRSI buffer data.");
     }

//--- STEP 2: Calculate Fast %K on the RSI buffer
   int k_start_pos = g_ExtLengthRSI + g_ExtLengthStoch - 2;
   for(int i = k_start_pos; i < rates_total; i++)
     {
      double highest_rsi = Highest(BufferRSI, g_ExtLengthStoch, i);
      double lowest_rsi  = Lowest(BufferRSI, g_ExtLengthStoch, i);

      double range = highest_rsi - lowest_rsi;
      if(range > 0.00001)
         BufferK[i] = (BufferRSI[i] - lowest_rsi) / range * 100.0;
      else
         BufferK[i] = (i > 0) ? BufferK[i-1] : 50.0;
     }

//--- STEP 3: Calculate %D (Signal Line) as an SMA of %K
   int d_start_pos = g_ExtLengthRSI + g_ExtLengthStoch + g_ExtSmoothD - 3;
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
