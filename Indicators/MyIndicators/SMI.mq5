//+------------------------------------------------------------------+
//|                                                          SMI.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Stochastic Momentum Index (SMI)"

#include <MovingAverages.mqh>

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_level1  40.0
#property indicator_level2  0.0
#property indicator_level3 -40.0
#property indicator_levelstyle STYLE_DOT

//--- Buffers and Plots ---
#property indicator_buffers 8 // SMI, Signal, and 6 calculation buffers
#property indicator_plots   2

//--- Plot 1: SMI line
#property indicator_label1  "SMI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal line (EMA of SMI)
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Input Parameters ---
input int InpLengthK   = 10; // %K Length
input int InpLengthD   = 3;  // %D Length (for double smoothing)
input int InpLengthEMA = 3;  // EMA Length (for signal line)
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // Applied Price

//--- Indicator Buffers ---
double    BufferSMI[];          // Final SMI line
double    BufferSignal[];       // Signal line (EMA of SMI)
// Calculation buffers
double    BufferHighestHigh[];
double    BufferLowestLow[];
double    BufferHighestLowestRange[];
double    BufferRelativeRange[];
double    BufferEmaEma_Relative[];  // Double EMA of Relative Range
double    BufferEmaEma_Range[];     // Double EMA of Highest-Lowest Range

//--- Global Variables ---
int       ExtLengthK, ExtLengthD, ExtLengthEMA;

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- Validate and store inputs
   ExtLengthK   = (InpLengthK < 1) ? 1 : InpLengthK;
   ExtLengthD   = (InpLengthD < 1) ? 1 : InpLengthD;
   ExtLengthEMA = (InpLengthEMA < 1) ? 1 : InpLengthEMA;

//--- Map the buffers
   SetIndexBuffer(0, BufferSMI,                INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal,             INDICATOR_DATA);
   SetIndexBuffer(2, BufferHighestHigh,        INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferLowestLow,          INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferHighestLowestRange, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferRelativeRange,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, BufferEmaEma_Relative,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, BufferEmaEma_Range,       INDICATOR_CALCULATIONS);

//--- FIX: Set all buffers to non-timeseries manually ---
   ArraySetAsSeries(BufferSMI,                false);
   ArraySetAsSeries(BufferSignal,             false);
   ArraySetAsSeries(BufferHighestHigh,        false);
   ArraySetAsSeries(BufferLowestLow,          false);
   ArraySetAsSeries(BufferHighestLowestRange, false);
   ArraySetAsSeries(BufferRelativeRange,      false);
   ArraySetAsSeries(BufferEmaEma_Relative,    false);
   ArraySetAsSeries(BufferEmaEma_Range,       false);

//--- Set indicator properties
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtLengthK + ExtLengthD - 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtLengthK + ExtLengthD + ExtLengthEMA - 3);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("SMI(%d,%d,%d)", ExtLengthK, ExtLengthD, ExtLengthEMA));
  }

//+------------------------------------------------------------------+
//| Stochastic Momentum Index calculation function.                  |
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
   if(rates_total < ExtLengthK + ExtLengthD)
      return(0);

//--- STEP 1-4: Calculate Highest, Lowest, and Ranges
   for(int i = ExtLengthK - 1; i < rates_total; i++)
     {
      BufferHighestHigh[i]        = Highest(high, ExtLengthK, i);
      BufferLowestLow[i]          = Lowest(low, ExtLengthK, i);
      BufferHighestLowestRange[i] = BufferHighestHigh[i] - BufferLowestLow[i];
      BufferRelativeRange[i]      = close[i] - (BufferHighestHigh[i] + BufferLowestLow[i]) / 2.0;
     }

//--- STEP 5: Double EMA Smoothing
// First EMA pass
   double temp_ema1[], temp_ema2[];
   ArrayResize(temp_ema1, rates_total);
   ArrayResize(temp_ema2, rates_total);

   for(int i = 1; i < rates_total; i++)
     {
      if(i < ExtLengthK - 1)
         continue;
      // EMA on RelativeRange
      temp_ema1[i] = ExponentialMA(i, ExtLengthD, temp_ema1[i-1], BufferRelativeRange);
      // EMA on HighestLowestRange
      temp_ema2[i] = ExponentialMA(i, ExtLengthD, temp_ema2[i-1], BufferHighestLowestRange);
     }

// Second EMA pass (EMA of EMA)
   for(int i = 1; i < rates_total; i++)
     {
      if(i < ExtLengthK + ExtLengthD - 2)
         continue;
      BufferEmaEma_Relative[i] = ExponentialMA(i, ExtLengthD, BufferEmaEma_Relative[i-1], temp_ema1);
      BufferEmaEma_Range[i]    = ExponentialMA(i, ExtLengthD, BufferEmaEma_Range[i-1], temp_ema2);
     }

//--- STEP 6: Calculate final SMI value
   for(int i = ExtLengthK + ExtLengthD - 2; i < rates_total; i++)
     {
      if(BufferEmaEma_Range[i] != 0)
         BufferSMI[i] = 200 * (BufferEmaEma_Relative[i] / BufferEmaEma_Range[i]);
      else
         BufferSMI[i] = 0;
     }

//--- STEP 7: Calculate the signal line (EMA of SMI)
   for(int i = ExtLengthK + ExtLengthD + ExtLengthEMA - 3; i < rates_total; i++)
     {
      BufferSignal[i] = ExponentialMA(i, ExtLengthEMA, BufferSignal[i-1], BufferSMI);
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
