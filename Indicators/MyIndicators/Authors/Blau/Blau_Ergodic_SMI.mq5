//+------------------------------------------------------------------+
//|                                         Blau_Ergodic_SMI.mq5     |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.01" // Added full MA type support for signal line
#property description "Ergodic Stochastic Momentum Index (SMI) by William Blau."
#property description "Combines SMI with an optional, configurable signal line."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 2 // SMI and Signal Line
#property indicator_plots   2
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_label1  "Ergodic SMI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_label2  "Signal"
#property indicator_style2  STYLE_DOT
#property indicator_level1 -40.0
#property indicator_level2  40.0
#property indicator_level3  0.0
#property indicator_levelstyle STYLE_DOT

//--- Input Parameters ---
input int                InpStochPeriod  = 5;       // Stochastic Period (%K)
input int                InpSlowPeriod   = 20;      // Slow EMA Period (1st smoothing)
input int                InpFastPeriod   = 5;       // Fast EMA Period (2nd smoothing)
input group              "Signal Line Settings"
input int                InpSignalPeriod = 5;       // Signal Line Period
input ENUM_MA_METHOD     InpSignalMAType = MODE_EMA;  // Signal Line MA Type

//--- Indicator Buffers ---
double    BufferSMI[];
double    BufferSignal[];

//--- Global Variables ---
int       g_ExtStochPeriod, g_ExtSlowPeriod, g_ExtFastPeriod, g_ExtSignalPeriod;

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtStochPeriod  = (InpStochPeriod < 1) ? 1 : InpStochPeriod;
   g_ExtSlowPeriod   = (InpSlowPeriod < 1) ? 1 : InpSlowPeriod;
   g_ExtFastPeriod   = (InpFastPeriod < 1) ? 1 : InpFastPeriod;
   g_ExtSignalPeriod = (InpSignalPeriod < 1) ? 1 : InpSignalPeriod;

   SetIndexBuffer(0, BufferSMI,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferSMI,    false);
   ArraySetAsSeries(BufferSignal, false);

   int smi_draw_begin = g_ExtStochPeriod + g_ExtSlowPeriod + g_ExtFastPeriod - 2;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, smi_draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, smi_draw_begin + g_ExtSignalPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Ergodic SMI(%d,%d,%d)", g_ExtStochPeriod, g_ExtSlowPeriod, g_ExtFastPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Ergodic SMI calculation function.                                |
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
   int start_pos = g_ExtStochPeriod + g_ExtSlowPeriod + g_ExtFastPeriod + g_ExtSignalPeriod - 2;
   if(rates_total <= start_pos)
      return(0);

//--- STEP 1: Calculate Stochastic Momentum (SM) and Range
   double sm[], range[];
   ArrayResize(sm, rates_total);
   ArrayResize(range, rates_total);
   for(int i = g_ExtStochPeriod - 1; i < rates_total; i++)
     {
      double highest_high = Highest(high, g_ExtStochPeriod, i);
      double lowest_low   = Lowest(low, g_ExtStochPeriod, i);

      sm[i] = close[i] - (highest_high + lowest_low) / 2.0;
      range[i] = highest_high - lowest_low;
     }

//--- STEP 2: First EMA Smoothing (Slow Period)
   double ema1_sm[], ema1_range[];
   ArrayResize(ema1_sm, rates_total);
   ArrayResize(ema1_range, rates_total);
   double pr_slow = 2.0 / (g_ExtSlowPeriod + 1.0);
   int ema1_start_pos = g_ExtStochPeriod + g_ExtSlowPeriod - 2;

   for(int i = ema1_start_pos; i < rates_total; i++)
     {
      if(i == ema1_start_pos)
        {
         double sum_sm=0, sum_range=0;
         for(int j=0; j<g_ExtSlowPeriod; j++)
           {
            sum_sm += sm[i-j];
            sum_range += range[i-j];
           }
         ema1_sm[i] = sum_sm / g_ExtSlowPeriod;
         ema1_range[i] = sum_range / g_ExtSlowPeriod;
        }
      else
        {
         ema1_sm[i] = sm[i] * pr_slow + ema1_sm[i-1] * (1.0 - pr_slow);
         ema1_range[i] = range[i] * pr_slow + ema1_range[i-1] * (1.0 - pr_slow);
        }
     }

//--- STEP 3: Second EMA Smoothing (Fast Period)
   double ema2_sm[], ema2_range[];
   ArrayResize(ema2_sm, rates_total);
   ArrayResize(ema2_range, rates_total);
   double pr_fast = 2.0 / (g_ExtFastPeriod + 1.0);
   int ema2_start_pos = ema1_start_pos + g_ExtFastPeriod - 1;

   for(int i = ema2_start_pos; i < rates_total; i++)
     {
      if(i == ema2_start_pos)
        {
         double sum_ema1=0, sum_range_ema1=0;
         for(int j=0; j<g_ExtFastPeriod; j++)
           {
            sum_ema1 += ema1_sm[i-j];
            sum_range_ema1 += ema1_range[i-j];
           }
         ema2_sm[i] = sum_ema1 / g_ExtFastPeriod;
         ema2_range[i] = sum_range_ema1 / g_ExtFastPeriod;
        }
      else
        {
         ema2_sm[i] = ema1_sm[i] * pr_fast + ema2_sm[i-1] * (1.0 - pr_fast);
         ema2_range[i] = ema1_range[i] * pr_fast + ema2_range[i-1] * (1.0 - pr_fast);
        }
     }

//--- STEP 4: Calculate final SMI value
   for(int i = ema2_start_pos; i < rates_total; i++)
     {
      if(ema2_range[i] != 0)
        {
         BufferSMI[i] = 100 * (ema2_sm[i] / (ema2_range[i] / 2.0));
        }
     }

//--- STEP 5: Calculate the Signal Line
   int signal_start_pos = ema2_start_pos + g_ExtSignalPeriod - 1;
   for(int i = signal_start_pos; i < rates_total; i++)
     {
      // --- FIX: Full, robust switch block for all MA types ---
      switch(InpSignalMAType)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == signal_start_pos)
              {
               double sum=0;
               for(int j=0; j<g_ExtSignalPeriod; j++)
                  sum+=BufferSMI[i-j];
               BufferSignal[i] = sum/g_ExtSignalPeriod;
              }
            else
              {
               if(InpSignalMAType == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtSignalPeriod+1.0);
                  BufferSignal[i] = BufferSMI[i]*pr + BufferSignal[i-1]*(1.0-pr);
                 }
               else
                  BufferSignal[i] = (BufferSignal[i-1]*(g_ExtSignalPeriod-1)+BufferSMI[i])/g_ExtSignalPeriod;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtSignalPeriod; j++)
              {
               int weight=g_ExtSignalPeriod-j;
               lwma_sum+=BufferSMI[i-j]*weight;
               weight_sum+=weight;
              }
            if(weight_sum>0)
               BufferSignal[i]=lwma_sum/weight_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<g_ExtSignalPeriod; j++)
               sum+=BufferSMI[i-j];
            BufferSignal[i] = sum/g_ExtSignalPeriod;
           }
         break;
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
      if(res < array[current_pos - i])
         res = array[current_pos - i];
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
      if(res > array[current_pos - i])
         res = array[current_pos - i];
     }
   return(res);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
