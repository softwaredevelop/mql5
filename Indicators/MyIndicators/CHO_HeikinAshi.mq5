//+------------------------------------------------------------------+
//|                                            CHO_HeikinAshi.mq5    |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.01" // Added selectable MA Method
#property description "Chaikin Oscillator on Heikin Ashi data with selectable MA type"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 4 // CHO, ADL, FastMA, SlowMA
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_label1  "HA_CHO"
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

//--- Input Parameters ---
input int                 InpFastPeriod = 3;
input int                 InpSlowPeriod = 10;
input ENUM_MA_METHOD      InpMaMethod   = MODE_EMA;
input ENUM_APPLIED_VOLUME InpVolumeType = VOLUME_TICK;

//--- Indicator Buffers ---
double    BufferCHO[];
double    BufferADL[];
double    BufferFastMA[];
double    BufferSlowMA[];

//--- Global Objects and Variables ---
int                       g_ExtFastPeriod, g_ExtSlowPeriod;
CHeikinAshi_Calculator   *g_ha_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtFastPeriod = (InpFastPeriod < 1) ? 1 : InpFastPeriod;
   g_ExtSlowPeriod = (InpSlowPeriod < 1) ? 1 : InpSlowPeriod;

   if(g_ExtFastPeriod > g_ExtSlowPeriod)
     {
      int temp = g_ExtFastPeriod;
      g_ExtFastPeriod = g_ExtSlowPeriod;
      g_ExtSlowPeriod = temp;
     }

   SetIndexBuffer(0, BufferCHO,      INDICATOR_DATA);
   SetIndexBuffer(1, BufferADL,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(2, BufferFastMA,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferSlowMA,   INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferCHO,      false);
   ArraySetAsSeries(BufferADL,      false);
   ArraySetAsSeries(BufferFastMA,   false);
   ArraySetAsSeries(BufferSlowMA,   false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtSlowPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_CHO(%d,%d)", g_ExtFastPeriod, g_ExtSlowPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 0);

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
//| Chaikin Oscillator on Heikin Ashi calculation function.          |
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
   if(rates_total < g_ExtSlowPeriod)
      return(0);

//--- Intermediate Heikin Ashi Buffers
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- STEP 2: Calculate Accumulation/Distribution Line (ADL) on HA data
   for(int i = 0; i < rates_total; i++)
     {
      double mfm = 0;
      double range = ha_high[i] - ha_low[i];
      if(range > 0)
        {
         mfm = ((ha_close[i] - ha_low[i]) - (ha_high[i] - ha_close[i])) / range;
        }
      long current_volume = (InpVolumeType == VOLUME_TICK) ? tick_volume[i] : volume[i];
      double mfv = mfm * current_volume;

      if(i > 0)
         BufferADL[i] = BufferADL[i-1] + mfv;
      else
         BufferADL[i] = mfv;
     }

//--- STEP 3: Calculate Fast MA on ADL
   for(int i = g_ExtFastPeriod - 1; i < rates_total; i++)
     {
      switch(InpMaMethod)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == g_ExtFastPeriod - 1)
              {
               double sum=0;
               for(int j=0; j<g_ExtFastPeriod; j++)
                  sum+=BufferADL[i-j];
               BufferFastMA[i] = sum/g_ExtFastPeriod;
              }
            else
              {
               if(InpMaMethod == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtFastPeriod+1.0);
                  BufferFastMA[i] = BufferADL[i]*pr + BufferFastMA[i-1]*(1.0-pr);
                 }
               else
                  BufferFastMA[i] = (BufferFastMA[i-1]*(g_ExtFastPeriod-1)+BufferADL[i])/g_ExtFastPeriod;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtFastPeriod; j++)
              {
               int weight=g_ExtFastPeriod-j;
               lwma_sum+=BufferADL[i-j]*weight;
               weight_sum+=weight;
              }
            if(weight_sum>0)
               BufferFastMA[i]=lwma_sum/weight_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<g_ExtFastPeriod; j++)
               sum+=BufferADL[i-j];
            BufferFastMA[i] = sum/g_ExtFastPeriod;
           }
         break;
        }
     }

//--- STEP 4: Calculate Slow MA on ADL
   for(int i = g_ExtSlowPeriod - 1; i < rates_total; i++)
     {
      switch(InpMaMethod)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == g_ExtSlowPeriod - 1)
              {
               double sum=0;
               for(int j=0; j<g_ExtSlowPeriod; j++)
                  sum+=BufferADL[i-j];
               BufferSlowMA[i] = sum/g_ExtSlowPeriod;
              }
            else
              {
               if(InpMaMethod == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtSlowPeriod+1.0);
                  BufferSlowMA[i] = BufferADL[i]*pr + BufferSlowMA[i-1]*(1.0-pr);
                 }
               else
                  BufferSlowMA[i] = (BufferSlowMA[i-1]*(g_ExtSlowPeriod-1)+BufferADL[i])/g_ExtSlowPeriod;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtSlowPeriod; j++)
              {
               int weight=g_ExtSlowPeriod-j;
               lwma_sum+=BufferADL[i-j]*weight;
               weight_sum+=weight;
              }
            if(weight_sum>0)
               BufferSlowMA[i]=lwma_sum/weight_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<g_ExtSlowPeriod; j++)
               sum+=BufferADL[i-j];
            BufferSlowMA[i] = sum/g_ExtSlowPeriod;
           }
         break;
        }
     }

//--- STEP 5: Calculate final Chaikin Oscillator value
   for(int i = g_ExtSlowPeriod - 1; i < rates_total; i++)
     {
      BufferCHO[i] = BufferFastMA[i] - BufferSlowMA[i];
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
