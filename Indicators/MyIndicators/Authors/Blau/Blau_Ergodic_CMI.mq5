//+------------------------------------------------------------------+
//|                                         Blau_Ergodic_CMI.mq5     |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.01" // Added full MA type support for signal line
#property description "Ergodic Candle Momentum Index (CMI) by William Blau."
#property description "Combines CMI with an optional, configurable signal line."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 2 // CMI and Signal Line
#property indicator_plots   2
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_label1  "Ergodic CMI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_label2  "Signal"
#property indicator_style2  STYLE_DOT
#property indicator_level1 -25.0
#property indicator_level2  25.0
#property indicator_level3  0.0
#property indicator_levelstyle STYLE_DOT

//--- Input Parameters ---
input int                InpSlowPeriod   = 20;      // Slow EMA Period (1st smoothing)
input int                InpFastPeriod   = 5;       // Fast EMA Period (2nd smoothing)
input group              "Signal Line Settings"
input int                InpSignalPeriod = 3;       // Signal Line Period
input ENUM_MA_METHOD     InpSignalMAType = MODE_EMA;  // Signal Line MA Type

//--- Indicator Buffers ---
double    BufferCMI[];
double    BufferSignal[];

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

   SetIndexBuffer(0, BufferCMI,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferCMI,    false);
   ArraySetAsSeries(BufferSignal, false);

   int cmi_draw_begin = g_ExtSlowPeriod + g_ExtFastPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, cmi_draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, cmi_draw_begin + g_ExtSignalPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Ergodic CMI(%d,%d,%d)", g_ExtSlowPeriod, g_ExtFastPeriod, g_ExtSignalPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Ergodic CMI calculation function.                                |
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

//--- STEP 4: Calculate final CMI value
   for(int i = ema2_start_pos; i < rates_total; i++)
     {
      if(ema2_abs_momentum[i] > 0)
        {
         BufferCMI[i] = 100 * (ema2_momentum[i] / ema2_abs_momentum[i]);
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
                  sum+=BufferCMI[i-j];
               BufferSignal[i] = sum/g_ExtSignalPeriod;
              }
            else
              {
               if(InpSignalMAType == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtSignalPeriod+1.0);
                  BufferSignal[i] = BufferCMI[i]*pr + BufferSignal[i-1]*(1.0-pr);
                 }
               else
                  BufferSignal[i] = (BufferSignal[i-1]*(g_ExtSignalPeriod-1)+BufferCMI[i])/g_ExtSignalPeriod;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtSignalPeriod; j++)
              {
               int weight=g_ExtSignalPeriod-j;
               lwma_sum+=BufferCMI[i-j]*weight;
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
               sum+=BufferCMI[i-j];
            BufferSignal[i] = sum/g_ExtSignalPeriod;
           }
         break;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
