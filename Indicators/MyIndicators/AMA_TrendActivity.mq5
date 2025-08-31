//+------------------------------------------------------------------+
//|                                          AMA_TrendActivity.mq5   |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Measures the trend activity (slope) of an AMA line using Arctan normalization."
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
#property indicator_maximum 0.5

//--- Input Parameters ---
input group              "AMA Settings"
input int                InpAmaPeriod    = 10;
input int                InpFastEmaPeriod= 2;
input int                InpSlowEmaPeriod= 30;
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE;
input group              "Activity Calculation Settings"
input int                InpAtrPeriod    = 14;
input int                InpSmoothingPeriod = 5;

//--- Indicator Buffers ---
double    BufferActivity[];

//--- Global Variables ---
int       g_ExtAmaPeriod, g_ExtFastEmaPeriod, g_ExtSlowEmaPeriod, g_ExtAtrPeriod, g_ExtSmoothingPeriod;
double    g_M_PI_2;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtAmaPeriod       = (InpAmaPeriod < 1) ? 1 : InpAmaPeriod;
   g_ExtFastEmaPeriod   = (InpFastEmaPeriod < 1) ? 1 : InpFastEmaPeriod;
   g_ExtSlowEmaPeriod   = (InpSlowEmaPeriod < 1) ? 1 : InpSlowEmaPeriod;
   g_ExtAtrPeriod       = (InpAtrPeriod < 1) ? 1 : InpAtrPeriod;
   g_ExtSmoothingPeriod = (InpSmoothingPeriod < 1) ? 1 : InpSmoothingPeriod;
   g_M_PI_2             = M_PI / 2.0;

   SetIndexBuffer(0, BufferActivity, INDICATOR_DATA);
   ArraySetAsSeries(BufferActivity, false);

   int draw_begin = g_ExtAmaPeriod + g_ExtAtrPeriod + g_ExtSmoothingPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("AMA Activity(%d,%d,%d)", g_ExtAmaPeriod, g_ExtAtrPeriod, g_ExtSmoothingPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 4);

   IndicatorSetDouble(INDICATOR_MINIMUM, 0.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 0.5);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| AMA Trend Activity calculation function.                         |
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
   int start_pos = g_ExtAmaPeriod + g_ExtAtrPeriod + g_ExtSmoothingPeriod;
   if(rates_total <= start_pos)
      return(0);

//--- STEP 1: Prepare the source price array for AMA
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
         default:
            price_source[i] = close[i];
            break;
        }
     }

//--- STEP 2: Calculate AMA
   double buffer_ama[];
   ArrayResize(buffer_ama, rates_total);
   double fast_sc = 2.0 / (g_ExtFastEmaPeriod + 1.0);
   double slow_sc = 2.0 / (g_ExtSlowEmaPeriod + 1.0);

   for(int i = 1; i < rates_total; i++)
     {
      if(i == g_ExtAmaPeriod)
        {
         buffer_ama[i] = price_source[i];
         continue;
        }
      if(i > g_ExtAmaPeriod)
        {
         double direction = MathAbs(price_source[i] - price_source[i - g_ExtAmaPeriod]);
         double volatility = 0;
         for(int j = 0; j < g_ExtAmaPeriod; j++)
           {
            volatility += MathAbs(price_source[i - j] - price_source[i - j - 1]);
           }
         double er = (volatility > 0) ? direction / volatility : 0;
         double ssc = er * (fast_sc - slow_sc) + slow_sc;
         double ssc_sq = ssc * ssc;
         buffer_ama[i] = buffer_ama[i-1] + ssc_sq * (price_source[i] - buffer_ama[i-1]);
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
   for(int i = g_ExtAmaPeriod + 1; i < rates_total; i++)
     {
      if(buffer_atr[i] > 0)
        {
         double raw_activity = MathAbs(buffer_ama[i] - buffer_ama[i-1]) / buffer_atr[i];
         scaled_activity[i] = MathArctan(raw_activity) / g_M_PI_2;
        }
     }

//--- STEP 5: Calculate Final Oscillator (SMA of Scaled Activity)
   double sum = 0;
   int final_start_pos = g_ExtAmaPeriod + g_ExtSmoothingPeriod;
   for(int i = g_ExtAmaPeriod + 1; i < rates_total; i++)
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
//+------------------------------------------------------------------+
