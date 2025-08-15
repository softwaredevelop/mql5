//+------------------------------------------------------------------+
//|                                        Gann_HiLo_HeikenAshi.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Gann HiLo Activator on Heiken Ashi data with selectable MA"

#include <MovingAverages.mqh>
#include <MyIncludes\HA_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   1

//--- Plot 1: Gann HiLo line
#property indicator_label1  "HA_Gann_HiLo"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrDodgerBlue, clrTomato
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int            InpPeriod   = 10;       // Period for High/Low averages
input ENUM_MA_METHOD InpMAMethod = MODE_SMA; // Method for High/Low averages

//--- Indicator Buffers ---
double    BufferHA_GannHiLo[];
double    BufferColor[];
double    BufferHiAvg[];
double    BufferLoAvg[];
double    BufferTrend[];

//--- Global Objects and Variables ---
int              ExtPeriod;
CHA_Calculator   g_ha_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
void OnInit()
  {
   ExtPeriod = (InpPeriod < 1) ? 1 : InpPeriod;

   SetIndexBuffer(0, BufferHA_GannHiLo, INDICATOR_DATA);
   SetIndexBuffer(1, BufferColor,       INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferHiAvg,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferLoAvg,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferTrend,       INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferHA_GannHiLo, false);
   ArraySetAsSeries(BufferColor,       false);
   ArraySetAsSeries(BufferHiAvg,       false);
   ArraySetAsSeries(BufferLoAvg,       false);
   ArraySetAsSeries(BufferTrend,       false);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_Gann_HiLo(%d)", ExtPeriod));
  }

//+------------------------------------------------------------------+
//| Gann HiLo on Heiken Ashi calculation function.                   |
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
   if(rates_total < ExtPeriod)
      return(0);

//--- STEP 1: Calculate Heiken Ashi bars using our toolkit
   if(!g_ha_calculator.Calculate(rates_total, 0, open, high, low, close))
      return(0);

//--- STEP 2: Calculate the two moving averages on HA High and HA Low
   for(int i = 1; i < rates_total; i++)
     {
      if(i < ExtPeriod - 1)
         continue;

      switch(InpMAMethod)
        {
         case MODE_EMA:
            if(i == ExtPeriod - 1)
              {
               BufferHiAvg[i] = SimpleMA(i, ExtPeriod, g_ha_calculator.ha_high);
               BufferLoAvg[i] = SimpleMA(i, ExtPeriod, g_ha_calculator.ha_low);
              }
            else
              {
               double pr = 2.0 / (ExtPeriod + 1.0);
               BufferHiAvg[i] = g_ha_calculator.ha_high[i] * pr + BufferHiAvg[i-1] * (1.0 - pr);
               BufferLoAvg[i] = g_ha_calculator.ha_low[i] * pr + BufferLoAvg[i-1] * (1.0 - pr);
              }
            break;
         case MODE_SMMA:
            if(i == ExtPeriod - 1)
              {
               BufferHiAvg[i] = SimpleMA(i, ExtPeriod, g_ha_calculator.ha_high);
               BufferLoAvg[i] = SimpleMA(i, ExtPeriod, g_ha_calculator.ha_low);
              }
            else
              {
               BufferHiAvg[i] = (BufferHiAvg[i-1] * (ExtPeriod - 1) + g_ha_calculator.ha_high[i]) / ExtPeriod;
               BufferLoAvg[i] = (BufferLoAvg[i-1] * (ExtPeriod - 1) + g_ha_calculator.ha_low[i]) / ExtPeriod;
              }
            break;
         case MODE_LWMA:
            BufferHiAvg[i] = LinearWeightedMA(i, ExtPeriod, g_ha_calculator.ha_high);
            BufferLoAvg[i] = LinearWeightedMA(i, ExtPeriod, g_ha_calculator.ha_low);
            break;
         default: // MODE_SMA
            BufferHiAvg[i] = SimpleMA(i, ExtPeriod, g_ha_calculator.ha_high);
            BufferLoAvg[i] = SimpleMA(i, ExtPeriod, g_ha_calculator.ha_low);
            break;
        }
     }

//--- STEP 3 & 4: Determine trend and set the final Gann HiLo value
   for(int i = 1; i < rates_total; i++)
     {
      if(i < ExtPeriod -1)
         continue;

      // Use HA Close to determine the trend
      if(g_ha_calculator.ha_close[i] > BufferHiAvg[i])
         BufferTrend[i] = 1; // Up trend
      else
         if(g_ha_calculator.ha_close[i] < BufferLoAvg[i])
            BufferTrend[i] = -1; // Down trend
         else
            BufferTrend[i] = BufferTrend[i-1];

      if(BufferTrend[i] == 1)
        {
         BufferHA_GannHiLo[i] = BufferLoAvg[i];
         BufferColor[i] = 0;
        }
      else
        {
         BufferHA_GannHiLo[i] = BufferHiAvg[i];
         BufferColor[i] = 1;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
