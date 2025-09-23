//+------------------------------------------------------------------+
//|                                             RSI_HeikinAshi.mq5   |
//|            Copyright 2025, xxxxxxxx (Based on MetaQuotes RSI)    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2025, xxxxxxxx"
#property link        ""
#property version     "4.01" // Harmonized with fully manual MA calculations
#property description "RSI on Heikin Ashi prices, with a Moving Average."

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 30.0
#property indicator_level2 50.0
#property indicator_level3 70.0

//--- Buffers and Plots ---
#property indicator_buffers 2 // RSI and its MA
#property indicator_plots   2

//--- Plot 1: RSI MA line (smoothed)
#property indicator_label1  "HA_RSIMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_DOT
#property indicator_width1  1

//--- Plot 2: RSI line (raw)
#property indicator_label2  "HA_RSI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Input Parameters ---
input int            InpPeriodRSI    = 14;
input group          "Signal Line Settings"
input int            InpPeriodMA     = 14;
input ENUM_MA_METHOD InpMethodMA     = MODE_SMA;

//--- Indicator Buffers ---
double    BufferHARSI_MA[];
double    BufferHARSI[];

//--- Global Objects and Variables ---
int                           g_ExtPeriodRSI, g_ExtPeriodMA;
CHeikinAshi_RSI_Calculator   *g_ha_rsi_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtPeriodRSI = (InpPeriodRSI < 1) ? 1 : InpPeriodRSI;
   g_ExtPeriodMA  = (InpPeriodMA < 1) ? 1 : InpPeriodMA;

   SetIndexBuffer(0, BufferHARSI_MA, INDICATOR_DATA);
   SetIndexBuffer(1, BufferHARSI,    INDICATOR_DATA);

   ArraySetAsSeries(BufferHARSI_MA, false);
   ArraySetAsSeries(BufferHARSI,    false);

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtPeriodRSI + g_ExtPeriodMA - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtPeriodRSI);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_RSI(%d, %d)", g_ExtPeriodRSI, g_ExtPeriodMA));

   g_ha_rsi_calculator = new CHeikinAshi_RSI_Calculator();
   if(CheckPointer(g_ha_rsi_calculator) == POINTER_INVALID)
     {
      Print("Error creating CHeikinAshi_RSI_Calculator object");
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_ha_rsi_calculator) != POINTER_INVALID)
     {
      delete g_ha_rsi_calculator;
      g_ha_rsi_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| RSI on Heikin Ashi calculation function.                         |
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
   int start_pos = g_ExtPeriodRSI + g_ExtPeriodMA;
   if(rates_total <= start_pos)
      return(0);

//--- STEP 1: Calculate Heikin Ashi RSI values using our toolkit
   if(!g_ha_rsi_calculator.Calculate(rates_total, g_ExtPeriodRSI, open, high, low, close, BufferHARSI))
     {
      Print("Heikin Ashi RSI calculation failed.");
      return(0);
     }

//--- STEP 2: Calculate the Signal Line (MA of HA RSI)
   int ma_start_pos = g_ExtPeriodRSI + g_ExtPeriodMA - 1;
   for(int i = ma_start_pos; i < rates_total; i++)
     {
      switch(InpMethodMA)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == ma_start_pos)
              {
               double sum=0;
               for(int j=0; j<g_ExtPeriodMA; j++)
                  sum+=BufferHARSI[i-j];
               BufferHARSI_MA[i] = sum/g_ExtPeriodMA;
              }
            else
              {
               if(InpMethodMA == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtPeriodMA+1.0);
                  BufferHARSI_MA[i] = BufferHARSI[i]*pr + BufferHARSI_MA[i-1]*(1.0-pr);
                 }
               else
                  BufferHARSI_MA[i] = (BufferHARSI_MA[i-1]*(g_ExtPeriodMA-1)+BufferHARSI[i])/g_ExtPeriodMA;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtPeriodMA; j++)
              {
               int weight=g_ExtPeriodMA-j;
               lwma_sum+=BufferHARSI[i-j]*weight;
               weight_sum+=weight;
              }
            if(weight_sum>0)
               BufferHARSI_MA[i]=lwma_sum/weight_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<g_ExtPeriodMA; j++)
               sum+=BufferHARSI[i-j];
            BufferHARSI_MA[i] = sum/g_ExtPeriodMA;
           }
         break;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
