//+------------------------------------------------------------------+
//|                                    Blau_Ergodic_DTI_HeikinAshi.mq5|
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Ergodic DTI on Heikin Ashi data, with a signal line."

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 2 // DTI and Signal Line
#property indicator_plots   2
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_label1  "HA_Ergodic_DTI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_label2  "HA_Signal"
#property indicator_style2  STYLE_DOT
#property indicator_level1 -25.0
#property indicator_level2  25.0
#property indicator_level3  0.0
#property indicator_levelstyle STYLE_DOT

//--- Input Parameters ---
input int                InpMomentumPeriod = 1;
input int                InpSlowPeriod   = 20;
input int                InpFastPeriod   = 5;
input group              "Signal Line Settings"
input int                InpSignalPeriod = 3;
input ENUM_MA_METHOD     InpSignalMAType = MODE_EMA;

//--- Indicator Buffers ---
double    BufferDTI[];
double    BufferSignal[];

//--- Global Objects and Variables ---
int                       g_ExtMomentumPeriod, g_ExtSlowPeriod, g_ExtFastPeriod, g_ExtSignalPeriod;
CHeikinAshi_Calculator   *g_ha_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtMomentumPeriod = (InpMomentumPeriod < 1) ? 1 : InpMomentumPeriod;
   g_ExtSlowPeriod     = (InpSlowPeriod < 1) ? 1 : InpSlowPeriod;
   g_ExtFastPeriod     = (InpFastPeriod < 1) ? 1 : InpFastPeriod;
   g_ExtSignalPeriod   = (InpSignalPeriod < 1) ? 1 : InpSignalPeriod;

   SetIndexBuffer(0, BufferDTI,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferDTI,    false);
   ArraySetAsSeries(BufferSignal, false);

   int dti_draw_begin = g_ExtMomentumPeriod + g_ExtSlowPeriod + g_ExtFastPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, dti_draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, dti_draw_begin + g_ExtSignalPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_Ergodic_DTI(%d,%d,%d)", g_ExtSlowPeriod, g_ExtFastPeriod, g_ExtSignalPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   g_ha_calculator = new CHeikinAshi_Calculator();
   if(CheckPointer(g_ha_calculator) == POINTER_INVALID)
     {
      Print("Error creating CHeikinAshi_Calculator object");
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
     {
      delete g_ha_calculator;
      g_ha_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Ergodic DTI on Heikin Ashi calculation function.                 |
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
   int start_pos = g_ExtMomentumPeriod + g_ExtSlowPeriod + g_ExtFastPeriod + g_ExtSignalPeriod;
   if(rates_total <= start_pos)
      return(0);

//--- Intermediate Heikin Ashi Buffers
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- STEP 2: Calculate Composite High/Low Momentum on HA data
   double hlm[], abs_hlm[];
   ArrayResize(hlm, rates_total);
   ArrayResize(abs_hlm, rates_total);
   for(int i = g_ExtMomentumPeriod; i < rates_total; i++)
     {
      double up_mtm = ha_high[i] - ha_high[i - g_ExtMomentumPeriod];
      if(up_mtm < 0)
         up_mtm = 0;

      double down_mtm = ha_low[i - g_ExtMomentumPeriod] - ha_low[i];
      if(down_mtm < 0)
         down_mtm = 0;

      hlm[i] = up_mtm - down_mtm;
      abs_hlm[i] = MathAbs(hlm[i]);
     }

//--- STEP 3: First EMA Smoothing (Slow Period)
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

//--- STEP 4: Second EMA Smoothing (Fast Period)
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

//--- STEP 5: Calculate final DTI value
   for(int i = ema2_start_pos; i < rates_total; i++)
     {
      if(ema2_abs_hlm[i] > 0)
        {
         BufferDTI[i] = 100 * (ema2_hlm[i] / ema2_abs_hlm[i]);
        }
     }

//--- STEP 6: Calculate the Signal Line
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
                  sum+=BufferDTI[i-j];
               BufferSignal[i] = sum/g_ExtSignalPeriod;
              }
            else
              {
               if(InpSignalMAType == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtSignalPeriod+1.0);
                  BufferSignal[i] = BufferDTI[i]*pr + BufferSignal[i-1]*(1.0-pr);
                 }
               else
                  BufferSignal[i] = (BufferSignal[i-1]*(g_ExtSignalPeriod-1)+BufferDTI[i])/g_ExtSignalPeriod;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtSignalPeriod; j++)
              {
               int weight=g_ExtSignalPeriod-j;
               lwma_sum+=BufferDTI[i-j]*weight;
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
               sum+=BufferDTI[i-j];
            BufferSignal[i] = sum/g_ExtSignalPeriod;
           }
         break;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
