//+------------------------------------------------------------------+
//|                                        CCI_Precise_Oscillator.mq5|
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "CCI Oscillator (Precise) - Histogram of CCI vs Signal Line"

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1 // Only the final Histogram buffer is needed
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1
#property indicator_label1  "CCI Oscillator"
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

//--- Input Parameters ---
input int                InpCCIPeriod    = 20;
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_TYPICAL;
input group              "Signal Line Settings"
input int                InpMAPeriod     = 14;
input ENUM_MA_METHOD     InpMAMethod     = MODE_SMA;

//--- Indicator Buffers ---
double    BufferOscillator[];

//--- Global Variables ---
int       g_ExtCCIPeriod, g_ExtMAPeriod;
const double CCI_CONSTANT = 0.015;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtCCIPeriod = (InpCCIPeriod < 1) ? 1 : InpCCIPeriod;
   g_ExtMAPeriod  = (InpMAPeriod < 1) ? 1 : InpMAPeriod;

   SetIndexBuffer(0, BufferOscillator, INDICATOR_DATA);
   ArraySetAsSeries(BufferOscillator, false);

   int cci_draw_begin = g_ExtCCIPeriod - 1;
   int draw_begin = cci_draw_begin + g_ExtMAPeriod - 1;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CCI Osc Precise(%d, %d)", g_ExtCCIPeriod, g_ExtMAPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| CCI Oscillator (Precise) calculation function.                   |
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
   int start_pos = g_ExtCCIPeriod + g_ExtMAPeriod - 1;
   if(rates_total < start_pos)
      return(0);

//--- Internal Buffers for calculation ---
   double buffer_cci[], buffer_signal[];
   ArrayResize(buffer_cci, rates_total);
   ArrayResize(buffer_signal, rates_total);

//--- STEP 1: Calculate CCI (Precise) internally ---
     {
      double price_source[];
      ArrayResize(price_source, rates_total);
      for(int i=0; i<rates_total; i++)
        {
         switch(InpAppliedPrice)
           {
            case PRICE_TYPICAL:
               price_source[i] = (high[i] + low[i] + close[i]) / 3.0;
               break;
            default:
               price_source[i] = close[i];
               break;
           }
        }

      for(int i = g_ExtCCIPeriod - 1; i < rates_total; i++)
        {
         double sma = 0;
         for(int j=0; j<g_ExtCCIPeriod; j++)
            sma += price_source[i-j];
         sma /= g_ExtCCIPeriod;

         double mad = 0;
         for(int j=0; j<g_ExtCCIPeriod; j++)
            mad += MathAbs(price_source[i-j] - sma);
         mad /= g_ExtCCIPeriod;

         if(mad > 0)
            buffer_cci[i] = (price_source[i] - sma) / (CCI_CONSTANT * mad);
        }
     }

//--- STEP 2: Calculate the Signal Line (MA of CCI) ---
   int ma_start_pos = g_ExtCCIPeriod + g_ExtMAPeriod - 2;
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
                  sum+=buffer_cci[i-j];
               buffer_signal[i] = sum/g_ExtMAPeriod;
              }
            else
              {
               if(InpMAMethod == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtMAPeriod+1.0);
                  buffer_signal[i] = buffer_cci[i]*pr + buffer_signal[i-1]*(1.0-pr);
                 }
               else
                  buffer_signal[i] = (buffer_signal[i-1]*(g_ExtMAPeriod-1)+buffer_cci[i])/g_ExtMAPeriod;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtMAPeriod; j++)
              {
               int weight=g_ExtMAPeriod-j;
               lwma_sum+=buffer_cci[i-j]*weight;
               weight_sum+=weight;
              }
            if(weight_sum>0)
               buffer_signal[i]=lwma_sum/weight_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<g_ExtMAPeriod; j++)
               sum+=buffer_cci[i-j];
            buffer_signal[i] = sum/g_ExtMAPeriod;
           }
         break;
        }
     }

//--- STEP 3: Calculate the final Oscillator value
   for(int i = ma_start_pos; i < rates_total; i++)
     {
      BufferOscillator[i] = buffer_cci[i] - buffer_signal[i];
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
