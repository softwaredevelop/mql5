//+------------------------------------------------------------------+
//|                                         VIDYA_TrendActivity.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "4.03" // Adjusted vertical scale
#property description "Measures the trend activity (slope) of a VIDYA line using Arctan normalization."
#property description "High values suggest a trending market, low values suggest a flat/ranging market."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2
#property indicator_label1  "Activity"
#property indicator_minimum 0.0
#property indicator_maximum 0.5 // Adjusted for better visualization

//--- Input Parameters ---
input group              "VIDYA Settings"
input int                InpPeriodCMO    = 9;
input int                InpPeriodEMA    = 12;
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE;
input group              "Activity Calculation Settings"
input int                InpAtrPeriod    = 14;
input int                InpSmoothingPeriod = 5;   // Final smoothing period for the oscillator

//--- Indicator Buffers ---
double    BufferActivity[];

//--- Global Variables ---
int       g_ExtPeriodCMO, g_ExtPeriodEMA, g_ExtAtrPeriod, g_ExtSmoothingPeriod;
double    g_M_PI_2;

//--- Forward declarations ---
double CalculateCMO(int position, int period, const double &price_array[]);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtPeriodCMO       = (InpPeriodCMO < 1) ? 1 : InpPeriodCMO;
   g_ExtPeriodEMA       = (InpPeriodEMA < 1) ? 1 : InpPeriodEMA;
   g_ExtAtrPeriod       = (InpAtrPeriod < 1) ? 1 : InpAtrPeriod;
   g_ExtSmoothingPeriod = (InpSmoothingPeriod < 1) ? 1 : InpSmoothingPeriod;
   g_M_PI_2             = M_PI / 2.0;

   SetIndexBuffer(0, BufferActivity, INDICATOR_DATA);
   ArraySetAsSeries(BufferActivity, false);

   int draw_begin = g_ExtPeriodCMO + g_ExtPeriodEMA + g_ExtAtrPeriod + g_ExtSmoothingPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("VIDYA Activity(%d,%d,%d,%d)", g_ExtPeriodCMO, g_ExtPeriodEMA, g_ExtAtrPeriod, g_ExtSmoothingPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 4);

//--- Programmatically set the vertical scale for better visualization
   IndicatorSetDouble(INDICATOR_MINIMUM, 0.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 0.5);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| VIDYA Trend Activity calculation function.                       |
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
   int start_pos = g_ExtPeriodCMO + g_ExtPeriodEMA + g_ExtAtrPeriod + g_ExtSmoothingPeriod;
   if(rates_total <= start_pos)
      return(0);

//--- STEP 1: Prepare the source price array for VIDYA
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

//--- STEP 2: Calculate VIDYA
   double buffer_vidya[];
   ArrayResize(buffer_vidya, rates_total);
   double alpha = 2.0 / (g_ExtPeriodEMA + 1.0);
   int vidya_start_pos = g_ExtPeriodCMO + g_ExtPeriodEMA;

   for(int i = 1; i < rates_total; i++)
     {
      if(i == vidya_start_pos)
        {
         double sum = 0;
         for(int j=0; j<g_ExtPeriodEMA; j++)
            sum += price_source[i-j];
         buffer_vidya[i] = sum / g_ExtPeriodEMA;
         continue;
        }
      if(i > vidya_start_pos)
        {
         double cmo = MathAbs(CalculateCMO(i, g_ExtPeriodCMO, price_source));
         buffer_vidya[i] = price_source[i] * alpha * cmo + buffer_vidya[i-1] * (1 - alpha * cmo);
        }
     }

//--- STEP 3: Calculate ATR
   double buffer_atr[];
   ArrayResize(buffer_atr, rates_total);
   double tr[];
   ArrayResize(tr, rates_total);
   for(int i = 1; i < rates_total; i++)
     {
      tr[i] = MathMax(high[i], close[i-1]) - MathMin(low[i], close[i-1]);
     }
   for(int i = 1; i < rates_total; i++)
     {
      if(i == g_ExtAtrPeriod)
        {
         double sum_tr = 0;
         for(int j = 1; j <= g_ExtAtrPeriod; j++)
            sum_tr += tr[j];
         buffer_atr[i] = sum_tr / g_ExtAtrPeriod;
        }
      else
         if(i > g_ExtAtrPeriod)
           {
            buffer_atr[i] = (buffer_atr[i-1] * (g_ExtAtrPeriod - 1) + tr[i]) / g_ExtAtrPeriod;
           }
     }

//--- STEP 4: Calculate Raw Activity and Scale it using MathArctan
   double scaled_activity[];
   ArrayResize(scaled_activity, rates_total);
   for(int i = vidya_start_pos + 1; i < rates_total; i++)
     {
      if(buffer_atr[i] > 0)
        {
         double raw_activity = MathAbs(buffer_vidya[i] - buffer_vidya[i-1]) / buffer_atr[i];
         scaled_activity[i] = MathArctan(raw_activity) / g_M_PI_2;
        }
     }

//--- STEP 5: Calculate Final Oscillator (SMA of Scaled Activity)
   double sum = 0;
   int final_start_pos = vidya_start_pos + g_ExtSmoothingPeriod;
   for(int i = vidya_start_pos + 1; i < rates_total; i++)
     {
      sum += scaled_activity[i];
      if(i >= final_start_pos)
        {
         if(i > final_start_pos)
           {
            sum -= scaled_activity[i - g_ExtSmoothingPeriod];
           }
         BufferActivity[i] = sum / g_ExtSmoothingPeriod;
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Calculates Chande Momentum Oscillator (CMO) for a given position |
//+------------------------------------------------------------------+
double CalculateCMO(int position, int period, const double &price_array[])
  {
   if(position < period)
      return 0.0;

   double sum_up = 0.0;
   double sum_down = 0.0;

   for(int i = 0; i < period; i++)
     {
      double diff = price_array[position - i] - price_array[position - i - 1];
      if(diff > 0.0)
         sum_up += diff;
      else
         sum_down += (-diff);
     }

   if(sum_up + sum_down == 0.0)
      return 0.0;

   return (sum_up - sum_down) / (sum_up + sum_down);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
