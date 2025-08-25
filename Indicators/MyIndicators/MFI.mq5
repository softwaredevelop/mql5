//+------------------------------------------------------------------+
//|                                                          MFI.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Added signal line and refactored for stability
#property description "Money Flow Index with a signal line."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 2 // MFI and Signal Line
#property indicator_plots   2
#property indicator_maximum 100.0
#property indicator_minimum 0.0
#property indicator_level1  20.0
#property indicator_level2  80.0
#property indicator_level3  50.0
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: MFI line
#property indicator_label1  "MFI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Input Parameters ---
input int                 InpMFIPeriod  = 14;
input ENUM_APPLIED_VOLUME InpVolumeType = VOLUME_TICK;
input group               "Signal Line Settings"
input int                 InpMAPeriod   = 9;
input ENUM_MA_METHOD      InpMAMethod   = MODE_SMA;

//--- Indicator Buffers ---
double    BufferMFI[];
double    BufferSignal[];

//--- Global Variables ---
int       g_ExtMFIPeriod, g_ExtMAPeriod;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtMFIPeriod = (InpMFIPeriod < 1) ? 1 : InpMFIPeriod;
   g_ExtMAPeriod  = (InpMAPeriod < 1) ? 1 : InpMAPeriod;

   SetIndexBuffer(0, BufferMFI,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferMFI,    false);
   ArraySetAsSeries(BufferSignal, false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtMFIPeriod);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtMFIPeriod + g_ExtMAPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MFI(%d, %d)", g_ExtMFIPeriod, g_ExtMAPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Money Flow Index calculation function.                           |
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
   int start_pos = g_ExtMFIPeriod + g_ExtMAPeriod;
   if(rates_total <= start_pos)
      return(0);

//--- STEP 1: Calculate Typical Price
   double typical_price[];
   ArrayResize(typical_price, rates_total);
   for(int i=0; i<rates_total; i++)
     {
      typical_price[i] = (high[i] + low[i] + close[i]) / 3.0;
     }

//--- STEP 2: Calculate Positive and Negative Money Flow
   double positive_mf[], negative_mf[];
   ArrayResize(positive_mf, rates_total);
   ArrayResize(negative_mf, rates_total);
   for(int i=1; i<rates_total; i++)
     {
      double raw_money_flow = typical_price[i] * ((InpVolumeType == VOLUME_TICK) ? tick_volume[i] : volume[i]);

      if(typical_price[i] > typical_price[i-1])
        {
         positive_mf[i] = raw_money_flow;
        }
      else
         if(typical_price[i] < typical_price[i-1])
           {
            negative_mf[i] = raw_money_flow;
           }
     }

//--- STEP 3: Calculate Money Flow Ratio and MFI using a sliding window sum
   double sum_pos = 0;
   double sum_neg = 0;
   for(int i = 1; i < rates_total; i++)
     {
      sum_pos += positive_mf[i];
      sum_neg += negative_mf[i];

      if(i > g_ExtMFIPeriod)
        {
         sum_pos -= positive_mf[i - g_ExtMFIPeriod];
         sum_neg -= negative_mf[i - g_ExtMFIPeriod];
        }

      if(i >= g_ExtMFIPeriod)
        {
         if(sum_neg > 0)
           {
            double money_ratio = sum_pos / sum_neg;
            BufferMFI[i] = 100.0 - (100.0 / (1.0 + money_ratio));
           }
         else
           {
            BufferMFI[i] = 100.0;
           }
        }
     }

//--- STEP 4: Calculate the Signal Line (MA of MFI)
   int ma_start_pos = g_ExtMFIPeriod + g_ExtMAPeriod - 1;
   for(int i = ma_start_pos; i < rates_total; i++)
     {
      switch(InpMAMethod)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == ma_start_pos)
              {
               double sum=0;
               for(int j=0; j<g_ExtMAPeriod; j++)
                  sum+=BufferMFI[i-j];
               BufferSignal[i] = sum/g_ExtMAPeriod;
              }
            else
              {
               if(InpMAMethod == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtMAPeriod+1.0);
                  BufferSignal[i] = BufferMFI[i]*pr + BufferSignal[i-1]*(1.0-pr);
                 }
               else
                  BufferSignal[i] = (BufferSignal[i-1]*(g_ExtMAPeriod-1)+BufferMFI[i])/g_ExtMAPeriod;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtMAPeriod; j++)
              {
               int weight=g_ExtMAPeriod-j;
               lwma_sum+=BufferMFI[i-j]*weight;
               weight_sum+=weight;
              }
            if(weight_sum>0)
               BufferSignal[i]=lwma_sum/weight_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<g_ExtMAPeriod; j++)
               sum+=BufferMFI[i-j];
            BufferSignal[i] = sum/g_ExtMAPeriod;
           }
         break;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
