//+------------------------------------------------------------------+
//|                               CCI_Precise_Oscillator_HeikinAshi.mq5|
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "CCI Oscillator (Precise) on Heikin Ashi data"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1
#property indicator_label1  "HA_CCI_Osc_Precise"
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

//--- Enum for selecting Heikin Ashi price source ---
enum ENUM_HA_APPLIED_PRICE
  {
   HA_PRICE_TYPICAL, // (HA_H + HA_L + HA_C) / 3
   HA_PRICE_CLOSE, HA_PRICE_OPEN, HA_PRICE_HIGH, HA_PRICE_LOW
  };

//--- Input Parameters ---
input int                   InpCCIPeriod    = 20;
input ENUM_HA_APPLIED_PRICE InpAppliedPrice = HA_PRICE_TYPICAL;
input group                 "Signal Line Settings"
input int                   InpMAPeriod     = 14;
input ENUM_MA_METHOD        InpMAMethod     = MODE_SMA;

//--- Indicator Buffers ---
double    BufferOscillator[];

//--- Global Objects and Variables ---
int                       g_ExtCCIPeriod, g_ExtMAPeriod;
const double              CCI_CONSTANT = 0.015;
CHeikinAshi_Calculator   *g_ha_calculator;

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
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_CCI_Osc_Precise(%d, %d)", g_ExtCCIPeriod, g_ExtMAPeriod));
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
//| CCI Oscillator (Precise) on Heikin Ashi calculation function.    |
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

//--- STEP 1: Calculate Heikin Ashi CCI internally ---
     {
      double ha_open[], ha_high[], ha_low[], ha_close[];
      ArrayResize(ha_open, rates_total);
      ArrayResize(ha_high, rates_total);
      ArrayResize(ha_low, rates_total);
      ArrayResize(ha_close, rates_total);
      g_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

      double ha_price_source[];
      ArrayResize(ha_price_source, rates_total);
      for(int i=0; i<rates_total; i++)
        {
         switch(InpAppliedPrice)
           {
            case HA_PRICE_OPEN:
               ha_price_source[i] = ha_open[i];
               break;
            case HA_PRICE_HIGH:
               ha_price_source[i] = ha_high[i];
               break;
            case HA_PRICE_LOW:
               ha_price_source[i] = ha_low[i];
               break;
            case HA_PRICE_CLOSE:
               ha_price_source[i] = ha_close[i];
               break;
            default:
               ha_price_source[i] = (ha_high[i] + ha_low[i] + ha_close[i]) / 3.0;
               break;
           }
        }

      for(int i = g_ExtCCIPeriod - 1; i < rates_total; i++)
        {
         double sma = 0;
         for(int j=0; j<g_ExtCCIPeriod; j++)
            sma += ha_price_source[i-j];
         sma /= g_ExtCCIPeriod;

         double mad = 0;
         for(int j=0; j<g_ExtCCIPeriod; j++)
            mad += MathAbs(ha_price_source[i-j] - sma);
         mad /= g_ExtCCIPeriod;

         if(mad > 0)
            buffer_cci[i] = (ha_price_source[i] - sma) / (CCI_CONSTANT * mad);
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
