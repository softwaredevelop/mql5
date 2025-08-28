//+------------------------------------------------------------------+
//|                                           CutlerRSI_Oscillator.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Cutler's RSI Oscillator (Histogram of RSI vs Signal Line)"

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1
#property indicator_label1  "Cutler's RSI Osc"
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

//--- Input Parameters ---
input int                InpPeriodRSI    = 14;
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE;
input group              "Signal Line Settings"
input int                InpPeriodMA     = 14;
input ENUM_MA_METHOD     InpMethodMA     = MODE_SMA;

//--- Indicator Buffers ---
double    BufferOscillator[];

//--- Global Variables ---
int       g_ExtPeriodRSI, g_ExtPeriodMA;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtPeriodRSI = (InpPeriodRSI < 1) ? 1 : InpPeriodRSI;
   g_ExtPeriodMA  = (InpPeriodMA < 1) ? 1 : InpPeriodMA;

   SetIndexBuffer(0, BufferOscillator, INDICATOR_DATA);
   ArraySetAsSeries(BufferOscillator, false);

   int draw_begin = g_ExtPeriodRSI + g_ExtPeriodMA - 1;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CutlerRSI Osc(%d,%d)", g_ExtPeriodRSI, g_ExtPeriodMA));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Cutler's RSI Oscillator calculation function.                    |
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

//--- Internal Buffers for calculation ---
   double buffer_rsi[], buffer_signal[];
   ArrayResize(buffer_rsi, rates_total);
   ArrayResize(buffer_signal, rates_total);

//--- STEP 1: Calculate Cutler's RSI internally ---
     {
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

      double sum_pos = 0, sum_neg = 0;
      for(int i = 1; i < rates_total; i++)
        {
         double diff = price_source[i] - price_source[i-1];
         double pos_change = (diff > 0) ? diff : 0;
         double neg_change = (diff < 0) ? -diff : 0;
         sum_pos += pos_change;
         sum_neg += neg_change;
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
               buffer_rsi[i] = 100.0 - (100.0 / (1.0 + rs));
              }
            else
               buffer_rsi[i] = 100.0;
           }
        }
     }

//--- STEP 2: Calculate the Signal Line (MA of Cutler's RSI) ---
   for(int i = start_pos; i < rates_total; i++)
     {
      switch(InpMethodMA)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == start_pos)
              {
               double sum=0;
               for(int j=0; j<g_ExtPeriodMA; j++)
                  sum+=buffer_rsi[i-j];
               buffer_signal[i] = sum/g_ExtPeriodMA;
              }
            else
              {
               if(InpMethodMA == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtPeriodMA+1.0);
                  buffer_signal[i] = buffer_rsi[i]*pr + buffer_signal[i-1]*(1.0-pr);
                 }
               else
                  buffer_signal[i] = (buffer_signal[i-1]*(g_ExtPeriodMA-1)+buffer_rsi[i])/g_ExtPeriodMA;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtPeriodMA; j++)
              {
               int weight=g_ExtPeriodMA-j;
               lwma_sum+=buffer_rsi[i-j]*weight;
               weight_sum+=weight;
              }
            if(weight_sum>0)
               buffer_signal[i]=lwma_sum/weight_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<g_ExtPeriodMA; j++)
               sum+=buffer_rsi[i-j];
            buffer_signal[i] = sum/g_ExtPeriodMA;
           }
         break;
        }
     }

//--- STEP 3: Calculate the final Oscillator value
   for(int i = start_pos; i < rates_total; i++)
     {
      BufferOscillator[i] = buffer_rsi[i] - buffer_signal[i];
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
