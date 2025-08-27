//+------------------------------------------------------------------+
//|                                             TSI_HeikinAshi.mq5   |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "True Strength Index (TSI) on Heikin Ashi data, with a signal line."

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 2 // TSI and Signal Line
#property indicator_plots   2
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_label1  "HA_TSI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_label2  "HA_Signal"
#property indicator_style2  STYLE_DOT
#property indicator_level1 -25.0
#property indicator_level2  25.0
#property indicator_level3  0.0
#property indicator_levelstyle STYLE_DOT

//--- Enum for selecting Heikin Ashi price source ---
enum ENUM_HA_APPLIED_PRICE
  {
   HA_PRICE_CLOSE, HA_PRICE_OPEN, HA_PRICE_HIGH, HA_PRICE_LOW
  };

//--- Input Parameters ---
input int                   InpSlowPeriod   = 25;
input int                   InpFastPeriod   = 13;
input ENUM_HA_APPLIED_PRICE InpAppliedPrice = HA_PRICE_CLOSE;
input group                 "Signal Line Settings"
input int                   InpSignalPeriod = 13;
input ENUM_MA_METHOD        InpSignalMAType = MODE_EMA;

//--- Indicator Buffers ---
double    BufferTSI[];
double    BufferSignal[];

//--- Global Objects and Variables ---
int                       g_ExtSlowPeriod, g_ExtFastPeriod, g_ExtSignalPeriod;
CHeikinAshi_Calculator   *g_ha_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtSlowPeriod   = (InpSlowPeriod < 1) ? 1 : InpSlowPeriod;
   g_ExtFastPeriod   = (InpFastPeriod < 1) ? 1 : InpFastPeriod;
   g_ExtSignalPeriod = (InpSignalPeriod < 1) ? 1 : InpSignalPeriod;

   SetIndexBuffer(0, BufferTSI,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferTSI,    false);
   ArraySetAsSeries(BufferSignal, false);

   int tsi_draw_begin = g_ExtSlowPeriod + g_ExtFastPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, tsi_draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, tsi_draw_begin + g_ExtSignalPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_TSI(%d,%d,%d)", g_ExtSlowPeriod, g_ExtFastPeriod, g_ExtSignalPeriod));
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
//| TSI on Heikin Ashi calculation function.                         |
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

//--- Intermediate Heikin Ashi Buffers
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- STEP 2: Prepare the Heikin Ashi source price array
   double ha_price_source[];
   ArrayResize(ha_price_source, rates_total);
   switch(InpAppliedPrice)
     {
      case HA_PRICE_OPEN:
         ArrayCopy(ha_price_source, ha_open);
         break;
      case HA_PRICE_HIGH:
         ArrayCopy(ha_price_source, ha_high);
         break;
      case HA_PRICE_LOW:
         ArrayCopy(ha_price_source, ha_low);
         break;
      default:
         ArrayCopy(ha_price_source, ha_close);
         break;
     }

//--- STEP 3: Calculate Momentum and its Absolute Value on HA data
   double momentum[], abs_momentum[];
   ArrayResize(momentum, rates_total);
   ArrayResize(abs_momentum, rates_total);
   for(int i=1; i<rates_total; i++)
     {
      momentum[i] = ha_price_source[i] - ha_price_source[i-1];
      abs_momentum[i] = MathAbs(momentum[i]);
     }

//--- STEP 4: First EMA Smoothing (Slow Period)
   double ema1_momentum[], ema1_abs_momentum[];
   ArrayResize(ema1_momentum, rates_total);
   ArrayResize(ema1_abs_momentum, rates_total);
   double pr_slow = 2.0 / (g_ExtSlowPeriod + 1.0);
   int ema1_start_pos = g_ExtSlowPeriod;

   for(int i = ema1_start_pos; i < rates_total; i++)
     {
      if(i == ema1_start_pos)
        {
         double sum_mtm=0, sum_abs_mtm=0;
         for(int j=1; j<=g_ExtSlowPeriod; j++)
           {
            sum_mtm += momentum[j];
            sum_abs_mtm += abs_momentum[j];
           }
         ema1_momentum[i] = sum_mtm / g_ExtSlowPeriod;
         ema1_abs_momentum[i] = sum_abs_mtm / g_ExtSlowPeriod;
        }
      else
        {
         ema1_momentum[i] = momentum[i] * pr_slow + ema1_momentum[i-1] * (1.0 - pr_slow);
         ema1_abs_momentum[i] = abs_momentum[i] * pr_slow + ema1_abs_momentum[i-1] * (1.0 - pr_slow);
        }
     }

//--- STEP 5: Second EMA Smoothing (Fast Period)
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

//--- STEP 6: Calculate final TSI value
   for(int i = ema2_start_pos; i < rates_total; i++)
     {
      if(ema2_abs_momentum[i] > 0)
        {
         BufferTSI[i] = 100 * (ema2_momentum[i] / ema2_abs_momentum[i]);
        }
     }

//--- STEP 7: Calculate the Signal Line
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
                  sum+=BufferTSI[i-j];
               BufferSignal[i] = sum/g_ExtSignalPeriod;
              }
            else
              {
               if(InpSignalMAType == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtSignalPeriod+1.0);
                  BufferSignal[i] = BufferTSI[i]*pr + BufferSignal[i-1]*(1.0-pr);
                 }
               else
                  BufferSignal[i] = (BufferSignal[i-1]*(g_ExtSignalPeriod-1)+BufferTSI[i])/g_ExtSignalPeriod;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtSignalPeriod; j++)
              {
               int weight=g_ExtSignalPeriod-j;
               lwma_sum+=BufferTSI[i-j]*weight;
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
               sum+=BufferTSI[i-j];
            BufferSignal[i] = sum/g_ExtSignalPeriod;
           }
         break;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+