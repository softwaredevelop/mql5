//+------------------------------------------------------------------+
//|                                     CutlerRSI_MA_HeikenAshi.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Cutler's RSI (SMA-based) on Heiken Ashi data, with a signal line."

#include <MovingAverages.mqh>
#include <MyIncludes\HA_Tools.mqh>

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 30.0
#property indicator_level2 50.0
#property indicator_level3 70.0

//--- Buffers and Plots ---
#property indicator_buffers 4 // CutlerRSI_MA, CutlerRSI, Pos, Neg
#property indicator_plots   2

//--- Plot 1: MA line (smoothed)
#property indicator_label1  "MA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_DOT
#property indicator_width1  1

//--- Plot 2: Cutler's RSI line (raw)
#property indicator_label2  "HA_CutlerRSI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Input Parameters ---
input int            InpPeriodRSI    = 14;       // RSI Period
input group          "Signal Line Settings"
input int            InpPeriodMA     = 14;       // MA Period
input ENUM_MA_METHOD InpMethodMA     = MODE_SMA; // MA Method

//--- Indicator Buffers ---
double    BufferCutlerRSI_MA[];
double    BufferCutlerRSI[];
double    BufferAvgPos[];
double    BufferAvgNeg[];

//--- Global Objects and Variables ---
int              ExtPeriodRSI;
int              ExtPeriodMA;
CHA_Calculator   g_ha_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
void OnInit()
  {
   ExtPeriodRSI = (InpPeriodRSI < 1) ? 1 : InpPeriodRSI;
   ExtPeriodMA  = (InpPeriodMA < 1) ? 1 : InpPeriodMA;

   SetIndexBuffer(0, BufferCutlerRSI_MA, INDICATOR_DATA);
   SetIndexBuffer(1, BufferCutlerRSI,    INDICATOR_DATA);
   SetIndexBuffer(2, BufferAvgPos,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferAvgNeg,       INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferCutlerRSI_MA, false);
   ArraySetAsSeries(BufferCutlerRSI,    false);
   ArraySetAsSeries(BufferAvgPos,       false);
   ArraySetAsSeries(BufferAvgNeg,       false);

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtPeriodRSI + ExtPeriodMA - 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtPeriodRSI);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_CutlerRSI(%d,%d)", ExtPeriodRSI, ExtPeriodMA));
  }

//+------------------------------------------------------------------+
//| Cutler's RSI on Heiken Ashi calculation function.                |
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
   if(rates_total < ExtPeriodRSI)
      return(0);

//--- STEP 1: Calculate Heiken Ashi bars
   if(!g_ha_calculator.Calculate(rates_total, 0, open, high, low, close))
      return(0);

//--- Create temporary buffers for raw changes
   double pos_changes[], neg_changes[];
   ArrayResize(pos_changes, rates_total);
   ArrayResize(neg_changes, rates_total);

//--- STEP 2: Calculate and separate price changes based on HA Close
   for(int i = 1; i < rates_total; i++)
     {
      double diff = g_ha_calculator.ha_close[i] - g_ha_calculator.ha_close[i-1];
      pos_changes[i] = (diff > 0) ? diff : 0;
      neg_changes[i] = (diff < 0) ? -diff : 0;
     }

//--- STEP 3: Smooth changes with SMA
   for(int i = ExtPeriodRSI; i < rates_total; i++)
     {
      BufferAvgPos[i] = SimpleMA(i, ExtPeriodRSI, pos_changes);
      BufferAvgNeg[i] = SimpleMA(i, ExtPeriodRSI, neg_changes);
     }

//--- STEP 4: Calculate final Cutler's RSI value
   for(int i = ExtPeriodRSI; i < rates_total; i++)
     {
      if(BufferAvgNeg[i] > 0)
        {
         double rs = BufferAvgPos[i] / BufferAvgNeg[i];
         BufferCutlerRSI[i] = 100.0 - (100.0 / (1.0 + rs));
        }
      else
        {
         BufferCutlerRSI[i] = 100.0;
        }
     }

//--- STEP 5: Calculate the signal line (MA of Cutler's RSI)
   if(rates_total < ExtPeriodRSI + ExtPeriodMA)
      return(rates_total);

   for(int i = 1; i < rates_total; i++)
     {
      if(i < ExtPeriodRSI + ExtPeriodMA - 2)
        {
         BufferCutlerRSI_MA[i] = EMPTY_VALUE;
         continue;
        }

      switch(InpMethodMA)
        {
         case MODE_EMA:
            if(i == ExtPeriodRSI + ExtPeriodMA - 2)
               BufferCutlerRSI_MA[i] = SimpleMA(i, ExtPeriodMA, BufferCutlerRSI);
            else
              {
               double pr = 2.0 / (ExtPeriodMA + 1.0);
               BufferCutlerRSI_MA[i] = BufferCutlerRSI[i] * pr + BufferCutlerRSI_MA[i-1] * (1.0 - pr);
              }
            break;
         case MODE_SMMA:
            if(i == ExtPeriodRSI + ExtPeriodMA - 2)
               BufferCutlerRSI_MA[i] = SimpleMA(i, ExtPeriodMA, BufferCutlerRSI);
            else
               BufferCutlerRSI_MA[i] = (BufferCutlerRSI_MA[i-1] * (ExtPeriodMA - 1) + BufferCutlerRSI[i]) / ExtPeriodMA;
            break;
         case MODE_LWMA:
            BufferCutlerRSI_MA[i] = LinearWeightedMA(i, ExtPeriodMA, BufferCutlerRSI);
            break;
         default: // MODE_SMA
            BufferCutlerRSI_MA[i] = SimpleMA(i, ExtPeriodMA, BufferCutlerRSI);
            break;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
