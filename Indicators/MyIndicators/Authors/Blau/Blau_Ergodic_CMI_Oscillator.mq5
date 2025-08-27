//+------------------------------------------------------------------+
//|                                Blau_Ergodic_CMI_Oscillator.mq5   |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Ergodic CMI Oscillator (Histogram of CMI vs Signal Line)"

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1 // Only the final Histogram buffer is needed
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1
#property indicator_label1  "CMI Oscillator"
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

//--- Input Parameters ---
input int                InpSlowPeriod   = 20;
input int                InpFastPeriod   = 5;
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE;
input group              "Signal Line Settings"
input int                InpSignalPeriod = 3;
input ENUM_MA_METHOD     InpSignalMAType = MODE_EMA;

//--- Indicator Buffers ---
double    BufferOscillator[];

//--- Global Variables ---
int       g_ExtSlowPeriod, g_ExtFastPeriod, g_ExtSignalPeriod;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtSlowPeriod   = (InpSlowPeriod < 1) ? 1 : InpSlowPeriod;
   g_ExtFastPeriod   = (InpFastPeriod < 1) ? 1 : InpFastPeriod;
   g_ExtSignalPeriod = (InpSignalPeriod < 1) ? 1 : InpSignalPeriod;

   SetIndexBuffer(0, BufferOscillator, INDICATOR_DATA);
   ArraySetAsSeries(BufferOscillator, false);

   int draw_begin = g_ExtSlowPeriod + g_ExtFastPeriod + g_ExtSignalPeriod - 1;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Ergodic CMI Osc(%d,%d,%d)", g_ExtSlowPeriod, g_ExtFastPeriod, g_ExtSignalPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Ergodic CMI Oscillator calculation function.                     |
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
   int start_pos = g_ExtSlowPeriod + g_ExtFastPeriod + g_ExtSignalPeriod;
   if(rates_total <= start_pos)
      return(0);

//--- STEP 1: Calculate Candle Momentum and its Absolute Value
   double c_momentum[], abs_c_momentum[];
   ArrayResize(c_momentum, rates_total);
   ArrayResize(abs_c_momentum, rates_total);
   for(int i=0; i<rates_total; i++)
     {
      c_momentum[i] = close[i] - open[i];
      abs_c_momentum[i] = MathAbs(c_momentum[i]);
     }

//--- STEP 2: First EMA Smoothing (Slow Period)
   double ema1_momentum[], ema1_abs_momentum[];
   ArrayResize(ema1_momentum, rates_total);
   ArrayResize(ema1_abs_momentum, rates_total);
   double pr_slow = 2.0 / (g_ExtSlowPeriod + 1.0);
   int ema1_start_pos = g_ExtSlowPeriod - 1;

   for(int i = ema1_start_pos; i < rates_total; i++)
     {
      if(i == ema1_start_pos)
        {
         double sum_mtm=0, sum_abs_mtm=0;
         for(int j=0; j<=ema1_start_pos; j++)
           {
            sum_mtm += c_momentum[j];
            sum_abs_mtm += abs_c_momentum[j];
           }
         ema1_momentum[i] = sum_mtm / g_ExtSlowPeriod;
         ema1_abs_momentum[i] = sum_abs_mtm / g_ExtSlowPeriod;
        }
      else
        {
         ema1_momentum[i] = c_momentum[i] * pr_slow + ema1_momentum[i-1] * (1.0 - pr_slow);
         ema1_abs_momentum[i] = abs_c_momentum[i] * pr_slow + ema1_abs_momentum[i-1] * (1.0 - pr_slow);
        }
     }

//--- STEP 3: Second EMA Smoothing (Fast Period)
   double ema2_momentum[], ema2_abs_momentum[];
   ArrayResize(ema2_momentum, rates_total);
   ArrayResize(ema2_abs_momentum, rates_total);
   double pr_fast = 2.0 / (g_ExtFastPeriod + 1.0);
   int ema2_start_pos = ema1_start_pos + g_ExtFastPeriod - 1;

   for(int i = ema2_start_pos; i < rates_total; i++)
     {
      if(i == ema2_start_pos)
        {
         double sum_ema1=0, sum_abs_ema1=0;
         for(int j=0; j<g_ExtFastPeriod; j++)
           {
            sum_ema1 += ema1_momentum[i-j];
            sum_abs_ema1 += ema1_abs_momentum[i-j];
           }
         ema2_momentum[i] = sum_ema1 / g_ExtFastPeriod;
         ema2_abs_momentum[i] = sum_abs_ema1 / g_ExtFastPeriod;
        }
      else
        {
         ema2_momentum[i] = ema1_momentum[i] * pr_fast + ema2_momentum[i-1] * (1.0 - pr_fast);
         ema2_abs_momentum[i] = ema1_abs_momentum[i] * pr_fast + ema2_abs_momentum[i-1] * (1.0 - pr_fast);
        }
     }

//--- STEP 4: Calculate final CMI value (internal buffer)
   double buffer_cmi[];
   ArrayResize(buffer_cmi, rates_total);
   for(int i = ema2_start_pos; i < rates_total; i++)
     {
      if(ema2_abs_momentum[i] > 0)
        {
         buffer_cmi[i] = 100 * (ema2_momentum[i] / ema2_abs_momentum[i]);
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
                  sum+=buffer_cmi[i-j];
               buffer_signal[i] = sum/g_ExtSignalPeriod;
              }
            else
              {
               if(InpSignalMAType == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtSignalPeriod+1.0);
                  buffer_signal[i] = buffer_cmi[i]*pr + buffer_signal[i-1]*(1.0-pr);
                 }
               else
                  buffer_signal[i] = (buffer_signal[i-1]*(g_ExtSignalPeriod-1)+buffer_cmi[i])/g_ExtSignalPeriod;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtSignalPeriod; j++)
              {
               int weight=g_ExtSignalPeriod-j;
               lwma_sum+=buffer_cmi[i-j]*weight;
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
               sum+=buffer_cmi[i-j];
            buffer_signal[i] = sum/g_ExtSignalPeriod;
           }
         break;
        }
     }

//--- STEP 6: Calculate the final Oscillator value
   for(int i = signal_start_pos; i < rates_total; i++)
     {
      BufferOscillator[i] = buffer_cmi[i] - buffer_signal[i];
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
