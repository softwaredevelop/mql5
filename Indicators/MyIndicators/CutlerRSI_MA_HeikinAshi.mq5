//+------------------------------------------------------------------+
//|                                    CutlerRSI_MA_HeikinAshi.mq5   |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.01" // Fixed EMA/SMMA overflow and optimized calculation
#property description "Cutler's RSI (SMA-based) on Heikin Ashi data, with a signal line."

#include <MovingAverages.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 30.0
#property indicator_level2 50.0
#property indicator_level3 70.0

//--- Buffers and Plots ---
#property indicator_buffers 2 // CutlerRSI and its MA
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

//--- Global Objects and Variables ---
int                       g_ExtPeriodRSI;
int                       g_ExtPeriodMA;
CHeikinAshi_Calculator   *g_ha_calculator; // Pointer to our Heikin Ashi calculator

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtPeriodRSI = (InpPeriodRSI < 1) ? 1 : InpPeriodRSI;
   g_ExtPeriodMA  = (InpPeriodMA < 1) ? 1 : InpPeriodMA;

   SetIndexBuffer(0, BufferCutlerRSI_MA, INDICATOR_DATA);
   SetIndexBuffer(1, BufferCutlerRSI,    INDICATOR_DATA);

   ArraySetAsSeries(BufferCutlerRSI_MA, false);
   ArraySetAsSeries(BufferCutlerRSI,    false);

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
// Correct the draw begin for the signal line
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtPeriodRSI + g_ExtPeriodMA - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtPeriodRSI);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_CutlerRSI(%d,%d)", g_ExtPeriodRSI, g_ExtPeriodMA));

//--- Create the calculator instance
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
//--- Free the calculator object to prevent memory leaks
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
     {
      delete g_ha_calculator;
      g_ha_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Cutler's RSI on Heikin Ashi calculation function.                |
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
   if(rates_total <= g_ExtPeriodRSI)
      return(0);

//--- Intermediate Heikin Ashi Buffers
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- STEP 2: Calculate Cutler's RSI (SMA-based)
   double sum_pos = 0, sum_neg = 0;
   for(int i = 1; i < rates_total; i++)
     {
      double diff = ha_close[i] - ha_close[i-1];
      double pos_change = (diff > 0) ? diff : 0;
      double neg_change = (diff < 0) ? -diff : 0;

      sum_pos += pos_change;
      sum_neg += neg_change;

      // Remove the oldest value from the sum once the window is full
      if(i > g_ExtPeriodRSI)
        {
         double old_diff = ha_close[i - g_ExtPeriodRSI] - ha_close[i - g_ExtPeriodRSI - 1];
         sum_pos -= (old_diff > 0) ? old_diff : 0;
         sum_neg -= (old_diff < 0) ? -old_diff : 0;
        }

      if(i >= g_ExtPeriodRSI)
        {
         if(sum_neg > 0)
           {
            double rs = (sum_pos / g_ExtPeriodRSI) / (sum_neg / g_ExtPeriodRSI);
            BufferCutlerRSI[i] = 100.0 - (100.0 / (1.0 + rs));
           }
         else
           {
            BufferCutlerRSI[i] = 100.0;
           }
        }
     }

//--- STEP 3: Calculate the signal line (MA of Cutler's RSI)
// --- FIX: Correct starting position for the MA calculation ---
   int ma_start_pos = g_ExtPeriodRSI + g_ExtPeriodMA - 1;
   for(int i = ma_start_pos; i < rates_total; i++)
     {
      switch(InpMethodMA)
        {
         case MODE_EMA:
            if(i == ma_start_pos)
              {
               double sum = 0;
               for(int j = 0; j < g_ExtPeriodMA; j++)
                  sum += BufferCutlerRSI[i - j];
               BufferCutlerRSI_MA[i] = sum / g_ExtPeriodMA;
              }
            else
              {
               double pr = 2.0 / (g_ExtPeriodMA + 1.0);
               BufferCutlerRSI_MA[i] = BufferCutlerRSI[i] * pr + BufferCutlerRSI_MA[i-1] * (1.0 - pr);
              }
            break;
         case MODE_SMMA:
            if(i == ma_start_pos)
              {
               double sum = 0;
               for(int j = 0; j < g_ExtPeriodMA; j++)
                  sum += BufferCutlerRSI[i - j];
               BufferCutlerRSI_MA[i] = sum / g_ExtPeriodMA;
              }
            else
               BufferCutlerRSI_MA[i] = (BufferCutlerRSI_MA[i-1] * (g_ExtPeriodMA - 1) + BufferCutlerRSI[i]) / g_ExtPeriodMA;
            break;
         case MODE_LWMA:
            BufferCutlerRSI_MA[i] = LinearWeightedMA(i, g_ExtPeriodMA, BufferCutlerRSI);
            break;
         default: // MODE_SMA
            BufferCutlerRSI_MA[i] = SimpleMA(i, g_ExtPeriodMA, BufferCutlerRSI);
            break;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
