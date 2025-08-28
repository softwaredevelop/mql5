//+------------------------------------------------------------------+
//|                                               CutlerRSI_MA.mq5   |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored for stability and efficiency
#property description "Cutler's RSI (SMA-based) with a signal line."

#include <MovingAverages.mqh>

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 30.0
#property indicator_level2 50.0
#property indicator_level3 70.0

//--- Buffers and Plots ---
#property indicator_buffers 2 // CutlerRSI and its MA
#property indicator_plots   2

//--- Plot 1: MA line (smoothed)
#property indicator_label1  "MA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_DOT
#property indicator_width1  1

//--- Plot 2: Cutler's RSI line (raw)
#property indicator_label2  "Cutler's RSI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Input Parameters ---
input int                InpPeriodRSI    = 14;       // RSI Period
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // RSI Applied Price
input group              "Signal Line Settings"
input int                InpPeriodMA     = 14;       // MA Period
input ENUM_MA_METHOD     InpMethodMA     = MODE_SMA; // MA Method

//--- Indicator Buffers ---
double    BufferCutlerRSI_MA[];
double    BufferCutlerRSI[];

//--- Global Variables ---
int       g_ExtPeriodRSI;
int       g_ExtPeriodMA;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtPeriodRSI = (InpPeriodRSI < 1) ? 1 : InpPeriodRSI;
   g_ExtPeriodMA  = (InpPeriodMA < 1) ? 1 : InpPeriodMA;

   SetIndexBuffer(0, BufferCutlerRSI_MA, INDICATOR_DATA);
   SetIndexBuffer(1, BufferCutlerRSI,    INDICATOR_DATA);

   ArraySetAsSeries(BufferCutlerRSI_MA, false);
   ArraySetAsSeries(BufferCutlerRSI,    false);

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtPeriodRSI + g_ExtPeriodMA - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtPeriodRSI);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CutlerRSI(%d,%d)", g_ExtPeriodRSI, g_ExtPeriodMA));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// No handles to release, but good practice to have the function
  }

//+------------------------------------------------------------------+
//| Cutler's RSI calculation function.                               |
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
   int start_pos = g_ExtPeriodRSI + g_ExtPeriodMA - 1;
   if(rates_total <= start_pos)
      return(0);

//--- STEP 1: Prepare the source price array
   double price_source[];
   ArrayResize(price_source, rates_total);
   for(int i=0; i<rates_total; i++)
     {
      switch(InpAppliedPrice)
        {
         case PRICE_OPEN:
            price_source[i] = open[i];
            break;
         case PRICE_HIGH:
            price_source[i] = high[i];
            break;
         case PRICE_LOW:
            price_source[i] = low[i];
            break;
         case PRICE_MEDIAN:
            price_source[i] = (high[i] + low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            price_source[i] = (high[i] + low[i] + close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            price_source[i]= (high[i] + low[i] + 2*close[i]) / 4.0;
            break;
         default:
            price_source[i] = close[i];
            break;
        }
     }

//--- STEP 2: Calculate Cutler's RSI (SMA-based) using a sliding window sum
   double sum_pos = 0, sum_neg = 0;
   for(int i = 1; i < rates_total; i++)
     {
      double diff = price_source[i] - price_source[i-1];
      double pos_change = (diff > 0) ? diff : 0;
      double neg_change = (diff < 0) ? -diff : 0;

      sum_pos += pos_change;
      sum_neg += neg_change;

      // Remove the oldest value from the sum once the window is full
      if(i > g_ExtPeriodRSI)
        {
         double old_diff = price_source[i - g_ExtPeriodRSI] - price_source[i - g_ExtPeriodRSI - 1];
         sum_pos -= (old_diff > 0) ? old_diff : 0;
         sum_neg -= (old_diff < 0) ? -old_diff : 0;
        }

      if(i >= g_ExtPeriodRSI)
        {
         if(sum_neg > 0)
           {
            double rs = (sum_pos / g_ExtPeriodRSI) / (sum_neg / g_ExtPeriodRSI);
            BufferCutlerRSI[i] = 100.0 - (100.0 / (1.0 + rs));
           }
         else
           {
            BufferCutlerRSI[i] = 100.0;
           }
        }
     }

//--- STEP 3: Calculate the signal line (MA of Cutler's RSI)
   int ma_start_pos = g_ExtPeriodRSI + g_ExtPeriodMA - 1;
   for(int i = ma_start_pos; i < rates_total; i++)
     {
      // --- FIX: Full, robust switch block for all MA types ---
      switch(InpMethodMA)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == ma_start_pos)
              {
               double sum=0;
               for(int j=0; j<g_ExtPeriodMA; j++)
                  sum+=BufferCutlerRSI[i-j];
               BufferCutlerRSI_MA[i] = sum/g_ExtPeriodMA;
              }
            else
              {
               if(InpMethodMA == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtPeriodMA+1.0);
                  BufferCutlerRSI_MA[i] = BufferCutlerRSI[i]*pr + BufferCutlerRSI_MA[i-1]*(1.0-pr);
                 }
               else
                  BufferCutlerRSI_MA[i] = (BufferCutlerRSI_MA[i-1]*(g_ExtPeriodMA-1)+BufferCutlerRSI[i])/g_ExtPeriodMA;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtPeriodMA; j++)
              {
               int weight=g_ExtPeriodMA-j;
               lwma_sum+=BufferCutlerRSI[i-j]*weight;
               weight_sum+=weight;
              }
            if(weight_sum>0)
               BufferCutlerRSI_MA[i]=lwma_sum/weight_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<g_ExtPeriodMA; j++)
               sum+=BufferCutlerRSI[i-j];
            BufferCutlerRSI_MA[i] = sum/g_ExtPeriodMA;
           }
         break;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
