//+------------------------------------------------------------------+
//|                                 Blau_Ergodic_SMI_Oscillator.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Ergodic SMI Oscillator (Histogram of SMI vs Signal Line)"

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1 // Only the final Histogram buffer is needed
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1
#property indicator_label1  "SMI Oscillator"
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

//--- Input Parameters ---
input int                InpStochPeriod  = 5;
input int                InpSlowPeriod   = 20;
input int                InpFastPeriod   = 5;
input group              "Signal Line Settings"
input int                InpSignalPeriod = 5;
input ENUM_MA_METHOD     InpSignalMAType = MODE_EMA;

//--- Indicator Buffers ---
double    BufferOscillator[];

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

   SetIndexBuffer(0, BufferOscillator, INDICATOR_DATA);
   ArraySetAsSeries(BufferOscillator, false);

   int draw_begin = g_ExtStochPeriod + g_ExtSlowPeriod + g_ExtFastPeriod + g_ExtSignalPeriod - 2;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Ergodic SMI Osc(%d,%d,%d,%d)", g_ExtStochPeriod, g_ExtSlowPeriod, g_ExtFastPeriod, g_ExtSignalPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Ergodic SMI Oscillator calculation function.                     |
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

//--- STEP 4: Calculate final SMI value (internal buffer)
   double buffer_smi[];
   ArrayResize(buffer_smi, rates_total);
   for(int i = ema2_start_pos; i < rates_total; i++)
     {
      if(ema2_range[i] != 0)
        {
         buffer_smi[i] = 100 * (ema2_sm[i] / (ema2_range[i] / 2.0));
        }
     }

//--- STEP 5: Calculate the Signal Line (internal buffer)
   double buffer_signal[];
   ArrayResize(buffer_signal, rates_total);
   int signal_start_pos = ema2_start_pos + g_ExtSignalPeriod - 1;
   for(int i = signal_start_pos; i < rates_total; i++)
     {
      switch(InpSignalMAType)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == signal_start_pos)
              {
               double sum=0;
               for(int j=0; j<g_ExtSignalPeriod; j++)
                  sum+=buffer_smi[i-j];
               buffer_signal[i] = sum/g_ExtSignalPeriod;
              }
            else
              {
               if(InpSignalMAType == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtSignalPeriod+1.0);
                  buffer_signal[i] = buffer_smi[i]*pr + buffer_signal[i-1]*(1.0-pr);
                 }
               else
                  buffer_signal[i] = (buffer_signal[i-1]*(g_ExtSignalPeriod-1)+buffer_smi[i])/g_ExtSignalPeriod;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtSignalPeriod; j++)
              {
               int weight=g_ExtSignalPeriod-j;
               lwma_sum+=buffer_smi[i-j]*weight;
               weight_sum+=weight;
              }
            if(weight_sum>0)
               buffer_signal[i]=lwma_sum/weight_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<g_ExtSignalPeriod; j++)
               sum+=buffer_smi[i-j];
            buffer_signal[i] = sum/g_ExtSignalPeriod;
           }
         break;
        }
     }

//--- STEP 6: Calculate the final Oscillator value
   for(int i = signal_start_pos; i < rates_total; i++)
     {
      BufferOscillator[i] = buffer_smi[i] - buffer_signal[i];
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
