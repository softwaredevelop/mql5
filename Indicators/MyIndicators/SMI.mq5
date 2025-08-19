//+------------------------------------------------------------------+
//|                                                          SMI.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored for stability and clarity
#property description "Stochastic Momentum Index (SMI)"

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_buffers 8 // SMI, Signal, and 6 calculation buffers
#property indicator_plots   2
#property indicator_level1  40.0
#property indicator_level2  0.0
#property indicator_level3 -40.0
#property indicator_levelstyle STYLE_DOT

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
double    BufferSMI[];
double    BufferSignal[];
double    BufferHighestLowestRange[];
double    BufferRelativeRange[];
double    BufferEma_Relative[];
double    BufferEma_Range[];
double    BufferEmaEma_Relative[];
double    BufferEmaEma_Range[];

//--- Global Variables ---
int       g_ExtLengthK, g_ExtLengthD, g_ExtLengthEMA;

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate and store inputs
   g_ExtLengthK   = (InpLengthK < 1) ? 1 : InpLengthK;
   g_ExtLengthD   = (InpLengthD < 1) ? 1 : InpLengthD;
   g_ExtLengthEMA = (InpLengthEMA < 1) ? 1 : InpLengthEMA;

//--- Map the buffers
   SetIndexBuffer(0, BufferSMI,                INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal,             INDICATOR_DATA);
   SetIndexBuffer(2, BufferHighestLowestRange, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferRelativeRange,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferEma_Relative,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferEma_Range,          INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, BufferEmaEma_Relative,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, BufferEmaEma_Range,       INDICATOR_CALCULATIONS);

//--- Set all buffers to non-timeseries
   ArraySetAsSeries(BufferSMI,                false);
   ArraySetAsSeries(BufferSignal,             false);
   ArraySetAsSeries(BufferHighestLowestRange, false);
   ArraySetAsSeries(BufferRelativeRange,      false);
   ArraySetAsSeries(BufferEma_Relative,       false);
   ArraySetAsSeries(BufferEma_Range,          false);
   ArraySetAsSeries(BufferEmaEma_Relative,    false);
   ArraySetAsSeries(BufferEmaEma_Range,       false);

//--- Set indicator properties
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   int smi_draw_begin = g_ExtLengthK + g_ExtLengthD + g_ExtLengthD - 3; // K + D + (D-1) for 2nd EMA
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, smi_draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, smi_draw_begin + g_ExtLengthEMA - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("SMI(%d,%d,%d)", g_ExtLengthK, g_ExtLengthD, g_ExtLengthEMA));

   return(INIT_SUCCEEDED);
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
   int start_pos = g_ExtLengthK + g_ExtLengthD + g_ExtLengthD + g_ExtLengthEMA - 4;
   if(rates_total <= start_pos)
      return(0);

//--- STEP 1: Calculate Highest, Lowest, and Ranges
   for(int i = g_ExtLengthK - 1; i < rates_total; i++)
     {
      double highest_high = Highest(high, g_ExtLengthK, i);
      double lowest_low   = Lowest(low, g_ExtLengthK, i);
      BufferHighestLowestRange[i] = highest_high - lowest_low;
      BufferRelativeRange[i]      = close[i] - (highest_high + lowest_low) / 2.0;
     }

//--- STEP 2-6: Calculate all smoothed values and final SMI in a single loop
   double pr_d = 2.0 / (g_ExtLengthD + 1.0);
   double pr_ema = 2.0 / (g_ExtLengthEMA + 1.0);

   int ema1_start = g_ExtLengthK + g_ExtLengthD - 2;
   int ema2_start = ema1_start + g_ExtLengthD - 1;
   int signal_start = ema2_start + g_ExtLengthEMA - 1;

   for(int i = g_ExtLengthK - 1; i < rates_total; i++)
     {
      // --- 1st EMA Smoothing ---
      if(i == g_ExtLengthK - 1) // Initialization
        {
         BufferEma_Relative[i] = BufferRelativeRange[i];
         BufferEma_Range[i] = BufferHighestLowestRange[i];
        }
      else // Recursive
        {
         BufferEma_Relative[i] = BufferRelativeRange[i] * pr_d + BufferEma_Relative[i-1] * (1.0 - pr_d);
         BufferEma_Range[i] = BufferHighestLowestRange[i] * pr_d + BufferEma_Range[i-1] * (1.0 - pr_d);
        }

      // --- 2nd EMA Smoothing ---
      if(i == ema2_start) // Initialization with manual SMA
        {
         double sum_rel=0, sum_ran=0;
         for(int j=0; j<g_ExtLengthD; j++)
           {
            sum_rel += BufferEma_Relative[i-j];
            sum_ran += BufferEma_Range[i-j];
           }
         BufferEmaEma_Relative[i] = sum_rel / g_ExtLengthD;
         BufferEmaEma_Range[i] = sum_ran / g_ExtLengthD;
        }
      else
         if(i > ema2_start) // Recursive
           {
            BufferEmaEma_Relative[i] = BufferEma_Relative[i] * pr_d + BufferEmaEma_Relative[i-1] * (1.0 - pr_d);
            BufferEmaEma_Range[i] = BufferEma_Range[i] * pr_d + BufferEmaEma_Range[i-1] * (1.0 - pr_d);
           }

      // --- Final SMI Value ---
      if(i >= ema2_start)
        {
         if(BufferEmaEma_Range[i] != 0)
            BufferSMI[i] = 100 * (BufferEmaEma_Relative[i] / (BufferEmaEma_Range[i] / 2.0));
         else
            BufferSMI[i] = 0;
        }

      // --- Signal Line ---
      if(i == signal_start) // Initialization with manual SMA
        {
         double sum_smi=0;
         for(int j=0; j<g_ExtLengthEMA; j++)
            sum_smi += BufferSMI[i-j];
         BufferSignal[i] = sum_smi / g_ExtLengthEMA;
        }
      else
         if(i > signal_start) // Recursive
           {
            BufferSignal[i] = BufferSMI[i] * pr_ema + BufferSignal[i-1] * (1.0 - pr_ema);
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
