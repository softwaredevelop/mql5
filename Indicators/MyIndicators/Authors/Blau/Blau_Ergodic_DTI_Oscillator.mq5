//+------------------------------------------------------------------+
//|                                Blau_Ergodic_DTI_Oscillator.mq5   |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Ergodic DTI Oscillator (Histogram of DTI vs Signal Line)"

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1 // Only the final Histogram buffer is needed
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1
#property indicator_label1  "DTI Oscillator"
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

//--- Input Parameters ---
input int                InpMomentumPeriod = 1;
input int                InpSlowPeriod   = 20;
input int                InpFastPeriod   = 5;
input group              "Signal Line Settings"
input int                InpSignalPeriod = 3;
input ENUM_MA_METHOD     InpSignalMAType = MODE_EMA;

//--- Indicator Buffers ---
double    BufferOscillator[];

//--- Global Variables ---
int       g_ExtMomentumPeriod, g_ExtSlowPeriod, g_ExtFastPeriod, g_ExtSignalPeriod;

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtMomentumPeriod = (InpMomentumPeriod < 1) ? 1 : InpMomentumPeriod;
   g_ExtSlowPeriod     = (InpSlowPeriod < 1) ? 1 : InpSlowPeriod;
   g_ExtFastPeriod     = (InpFastPeriod < 1) ? 1 : InpFastPeriod;
   g_ExtSignalPeriod   = (InpSignalPeriod < 1) ? 1 : InpSignalPeriod;

   SetIndexBuffer(0, BufferOscillator, INDICATOR_DATA);
   ArraySetAsSeries(BufferOscillator, false);

   int draw_begin = g_ExtMomentumPeriod + g_ExtSlowPeriod + g_ExtFastPeriod + g_ExtSignalPeriod - 1;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Ergodic DTI Osc(%d,%d,%d,%d)", g_ExtMomentumPeriod, g_ExtSlowPeriod, g_ExtFastPeriod, g_ExtSignalPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Ergodic DTI Oscillator calculation function.                     |
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
   int start_pos = g_ExtMomentumPeriod + g_ExtSlowPeriod + g_ExtFastPeriod + g_ExtSignalPeriod - 1;
   if(rates_total <= start_pos)
      return(0);

//--- STEP 1: Calculate Composite High/Low Momentum and its Absolute Value
   double hlm[], abs_hlm[];
   ArrayResize(hlm, rates_total);
   ArrayResize(abs_hlm, rates_total);
   for(int i = g_ExtMomentumPeriod; i < rates_total; i++)
     {
      double up_mtm = high[i] - high[i - g_ExtMomentumPeriod];
      if(up_mtm < 0)
         up_mtm = 0;

      double down_mtm = low[i - g_ExtMomentumPeriod] - low[i];
      if(down_mtm < 0)
         down_mtm = 0;

      hlm[i] = up_mtm - down_mtm;
      abs_hlm[i] = MathAbs(hlm[i]);
     }

//--- STEP 2: First EMA Smoothing (Slow Period)
   double ema1_hlm[], ema1_abs_hlm[];
   ArrayResize(ema1_hlm, rates_total);
   ArrayResize(ema1_abs_hlm, rates_total);
   double pr_slow = 2.0 / (g_ExtSlowPeriod + 1.0);
   int ema1_start_pos = g_ExtMomentumPeriod + g_ExtSlowPeriod -1;

   for(int i = ema1_start_pos; i < rates_total; i++)
     {
      if(i == ema1_start_pos)
        {
         double sum_hlm=0, sum_abs_hlm=0;
         for(int j=0; j<g_ExtSlowPeriod; j++)
           {
            sum_hlm += hlm[i-j];
            sum_abs_hlm += abs_hlm[i-j];
           }
         ema1_hlm[i] = sum_hlm / g_ExtSlowPeriod;
         ema1_abs_hlm[i] = sum_abs_hlm / g_ExtSlowPeriod;
        }
      else
        {
         ema1_hlm[i] = hlm[i] * pr_slow + ema1_hlm[i-1] * (1.0 - pr_slow);
         ema1_abs_hlm[i] = abs_hlm[i] * pr_slow + ema1_abs_hlm[i-1] * (1.0 - pr_slow);
        }
     }

//--- STEP 3: Second EMA Smoothing (Fast Period)
   double ema2_hlm[], ema2_abs_hlm[];
   ArrayResize(ema2_hlm, rates_total);
   ArrayResize(ema2_abs_hlm, rates_total);
   double pr_fast = 2.0 / (g_ExtFastPeriod + 1.0);
   int ema2_start_pos = ema1_start_pos + g_ExtFastPeriod - 1;

   for(int i = ema2_start_pos; i < rates_total; i++)
     {
      if(i == ema2_start_pos)
        {
         double sum_ema1=0, sum_abs_ema1=0;
         for(int j=0; j<g_ExtFastPeriod; j++)
           {
            sum_ema1 += ema1_hlm[i-j];
            sum_abs_ema1 += ema1_abs_hlm[i-j];
           }
         ema2_hlm[i] = sum_ema1 / g_ExtFastPeriod;
         ema2_abs_hlm[i] = sum_abs_ema1 / g_ExtFastPeriod;
        }
      else
        {
         ema2_hlm[i] = ema1_hlm[i] * pr_fast + ema2_hlm[i-1] * (1.0 - pr_fast);
         ema2_abs_hlm[i] = ema1_abs_hlm[i] * pr_fast + ema2_abs_hlm[i-1] * (1.0 - pr_fast);
        }
     }

//--- STEP 4: Calculate final DTI value (internal buffer)
   double buffer_dti[];
   ArrayResize(buffer_dti, rates_total);
   for(int i = ema2_start_pos; i < rates_total; i++)
     {
      if(ema2_abs_hlm[i] > 0)
        {
         buffer_dti[i] = 100 * (ema2_hlm[i] / ema2_abs_hlm[i]);
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
                  sum+=buffer_dti[i-j];
               buffer_signal[i] = sum/g_ExtSignalPeriod;
              }
            else
              {
               if(InpSignalMAType == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtSignalPeriod+1.0);
                  buffer_signal[i] = buffer_dti[i]*pr + buffer_signal[i-1]*(1.0-pr);
                 }
               else
                  buffer_signal[i] = (buffer_signal[i-1]*(g_ExtSignalPeriod-1)+buffer_dti[i])/g_ExtSignalPeriod;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtSignalPeriod; j++)
              {
               int weight=g_ExtSignalPeriod-j;
               lwma_sum+=buffer_dti[i-j]*weight;
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
               sum+=buffer_dti[i-j];
            buffer_signal[i] = sum/g_ExtSignalPeriod;
           }
         break;
        }
     }

//--- STEP 6: Calculate the final Oscillator value
   for(int i = signal_start_pos; i < rates_total; i++)
     {
      BufferOscillator[i] = buffer_dti[i] - buffer_signal[i];
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
