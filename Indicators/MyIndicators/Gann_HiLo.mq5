//+------------------------------------------------------------------+
//|                                                    Gann_HiLo.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored for stability with fully manual MA calculations
#property description "Gann HiLo Activator with selectable MA for trend following"

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   1

//--- Plot 1: Gann HiLo line
#property indicator_label1  "Gann_HiLo"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrDodgerBlue, clrTomato
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int            InpPeriod   = 10;       // Period for High/Low averages
input ENUM_MA_METHOD InpMAMethod = MODE_SMA; // Method for High/Low averages

//--- Indicator Buffers ---
double    BufferGannHiLo[];
double    BufferColor[];
double    BufferHiAvg[];
double    BufferLoAvg[];
double    BufferTrend[];

//--- Global Variables ---
int       g_ExtPeriod;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtPeriod = (InpPeriod < 1) ? 1 : InpPeriod;

   SetIndexBuffer(0, BufferGannHiLo, INDICATOR_DATA);
   SetIndexBuffer(1, BufferColor,    INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferHiAvg,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferLoAvg,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferTrend,    INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferGannHiLo, false);
   ArraySetAsSeries(BufferColor,    false);
   ArraySetAsSeries(BufferHiAvg,    false);
   ArraySetAsSeries(BufferLoAvg,    false);
   ArraySetAsSeries(BufferTrend,    false);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Gann_HiLo(%d)", g_ExtPeriod));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Gann HiLo Activator calculation function.                        |
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
   if(rates_total <= g_ExtPeriod)
      return(0);

//--- Variables for manual SMA calculation
   double sma_sum_high = 0;
   double sma_sum_low = 0;

//--- Main calculation loop
   for(int i = 1; i < rates_total; i++)
     {
      if(i < g_ExtPeriod - 1)
         continue;

      // --- STEP 1: Calculate the two moving averages (High and Low) ---
      switch(InpMAMethod)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == g_ExtPeriod - 1) // Initialization with manual SMA
              {
               double sum_h=0, sum_l=0;
               for(int j=0; j<g_ExtPeriod; j++)
                 {
                  sum_h += high[i-j];
                  sum_l += low[i-j];
                 }
               BufferHiAvg[i] = sum_h / g_ExtPeriod;
               BufferLoAvg[i] = sum_l / g_ExtPeriod;
              }
            else // Recursive calculation
              {
               if(InpMAMethod == MODE_EMA)
                 {
                  double pr = 2.0 / (g_ExtPeriod + 1.0);
                  BufferHiAvg[i] = high[i] * pr + BufferHiAvg[i-1] * (1.0 - pr);
                  BufferLoAvg[i] = low[i] * pr + BufferLoAvg[i-1] * (1.0 - pr);
                 }
               else
                 {
                  BufferHiAvg[i] = (BufferHiAvg[i-1] * (g_ExtPeriod - 1) + high[i]) / g_ExtPeriod;
                  BufferLoAvg[i] = (BufferLoAvg[i-1] * (g_ExtPeriod - 1) + low[i]) / g_ExtPeriod;
                 }
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum_h=0, lwma_sum_l=0;
            double weight_sum=0;
            for(int j=0; j<g_ExtPeriod; j++)
              {
               int weight = g_ExtPeriod - j;
               lwma_sum_h += high[i-j] * weight;
               lwma_sum_l += low[i-j] * weight;
               weight_sum += weight;
              }
            if(weight_sum > 0)
              {
               BufferHiAvg[i] = lwma_sum_h / weight_sum;
               BufferLoAvg[i] = lwma_sum_l / weight_sum;
              }
           }
         break;
         default: // MODE_SMA
            if(i == g_ExtPeriod - 1)
              {
               for(int j=0; j<g_ExtPeriod; j++)
                 {
                  sma_sum_high += high[i-j];
                  sma_sum_low += low[i-j];
                 }
              }
            else
              {
               sma_sum_high += high[i] - high[i - g_ExtPeriod];
               sma_sum_low += low[i] - low[i - g_ExtPeriod];
              }
            BufferHiAvg[i] = sma_sum_high / g_ExtPeriod;
            BufferLoAvg[i] = sma_sum_low / g_ExtPeriod;
            break;
        }

      // --- STEP 2: Determine trend and set the final Gann HiLo value ---
      if(i < g_ExtPeriod)
         continue; // Trend logic starts one bar later

      if(close[i] > BufferHiAvg[i-1])
         BufferTrend[i] = 1;
      else
         if(close[i] < BufferLoAvg[i-1])
            BufferTrend[i] = -1;
         else
            BufferTrend[i] = BufferTrend[i-1];

      if(BufferTrend[i] == 1)
        {
         BufferGannHiLo[i] = BufferLoAvg[i];
         BufferColor[i] = 0;
         if(BufferTrend[i-1] == -1)
            BufferGannHiLo[i-1] = BufferLoAvg[i];
        }
      else
        {
         BufferGannHiLo[i] = BufferHiAvg[i];
         BufferColor[i] = 1;
         if(BufferTrend[i-1] == 1)
            BufferGannHiLo[i-1] = BufferHiAvg[i];
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
