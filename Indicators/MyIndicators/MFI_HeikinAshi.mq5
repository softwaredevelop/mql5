//+------------------------------------------------------------------+
//|                                              MFI_HeikinAshi.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.01" // Corrected volume source handling
#property description "Money Flow Index on Heikin Ashi data, with a signal line."

#include <MyIncludes\HeikinAshi_Tools.mqh>

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
#property indicator_label1  "HA_MFI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal line
#property indicator_label2  "HA_Signal"
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

//--- Global Objects and Variables ---
int                       g_ExtMFIPeriod, g_ExtMAPeriod;
CHeikinAshi_Calculator   *g_ha_calculator;

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
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_MFI(%d, %d)", g_ExtMFIPeriod, g_ExtMAPeriod));
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
//| MFI on Heikin Ashi calculation function.                         |
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

//--- Intermediate Heikin Ashi Buffers
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- STEP 2: Calculate HA Typical Price and Raw Money Flow
   double ha_typical_price[], raw_money_flow[];
   ArrayResize(ha_typical_price, rates_total);
   ArrayResize(raw_money_flow, rates_total);
   for(int i=0; i<rates_total; i++)
     {
      ha_typical_price[i] = (ha_high[i] + ha_low[i] + ha_close[i]) / 3.0;
      // --- FIX: Use ternary operator to select volume source ---
      raw_money_flow[i] = ha_typical_price[i] * ((InpVolumeType == VOLUME_TICK) ? tick_volume[i] : volume[i]);
     }

//--- STEP 3: Calculate Positive and Negative Money Flow
   double positive_mf[], negative_mf[];
   ArrayResize(positive_mf, rates_total);
   ArrayResize(negative_mf, rates_total);
   for(int i=1; i<rates_total; i++)
     {
      if(ha_typical_price[i] > ha_typical_price[i-1])
        {
         positive_mf[i] = raw_money_flow[i];
        }
      else
         if(ha_typical_price[i] < ha_typical_price[i-1])
           {
            negative_mf[i] = raw_money_flow[i];
           }
     }

//--- STEP 4: Calculate Money Flow Ratio and MFI using a sliding window sum
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

//--- STEP 5: Calculate the Signal Line (MA of MFI)
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
