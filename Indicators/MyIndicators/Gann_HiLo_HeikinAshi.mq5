//+------------------------------------------------------------------+
//|                                       Gann_HiLo_HeikinAshi.mq5   |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored for full recalculation and stability
#property description "Gann HiLo Activator on Heikin Ashi data with selectable MA"

#include <MovingAverages.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

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

//--- Intermediate Heikin Ashi Buffers ---
double    ExtHaOpenBuffer[];
double    ExtHaHighBuffer[];
double    ExtHaLowBuffer[];
double    ExtHaCloseBuffer[];

//--- Global Objects and Variables ---
int                       g_ExtPeriod;
CHeikinAshi_Calculator   *g_ha_calculator; // Pointer to our Heikin Ashi calculator

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtPeriod = (InpPeriod < 1) ? 1 : InpPeriod;

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
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_Gann_HiLo(%d)", g_ExtPeriod));

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
//| Gann HiLo on Heikin Ashi calculation function.                   |
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

//--- Resize intermediate buffers
   ArrayResize(ExtHaOpenBuffer, rates_total);
   ArrayResize(ExtHaHighBuffer, rates_total);
   ArrayResize(ExtHaLowBuffer, rates_total);
   ArrayResize(ExtHaCloseBuffer, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close,
                             ExtHaOpenBuffer, ExtHaHighBuffer, ExtHaLowBuffer, ExtHaCloseBuffer);

//--- STEP 2 & 3: Calculate MAs, determine trend, and set final value in a single loop
   for(int i = 1; i < rates_total; i++)
     {
      // Skip bars that don't have enough history for the period
      if(i < g_ExtPeriod)
         continue;

      // --- Calculate the two moving averages on HA High and HA Low ---
      switch(InpMAMethod)
        {
         case MODE_EMA:
            if(i == g_ExtPeriod) // Initialization
              {
               BufferHiAvg[i] = SimpleMA(i, g_ExtPeriod, ExtHaHighBuffer);
               BufferLoAvg[i] = SimpleMA(i, g_ExtPeriod, ExtHaLowBuffer);
              }
            else // Recursive calculation
              {
               double pr = 2.0 / (g_ExtPeriod + 1.0);
               BufferHiAvg[i] = ExtHaHighBuffer[i] * pr + BufferHiAvg[i-1] * (1.0 - pr);
               BufferLoAvg[i] = ExtHaLowBuffer[i] * pr + BufferLoAvg[i-1] * (1.0 - pr);
              }
            break;
         case MODE_SMMA:
            if(i == g_ExtPeriod) // Initialization
              {
               BufferHiAvg[i] = SimpleMA(i, g_ExtPeriod, ExtHaHighBuffer);
               BufferLoAvg[i] = SimpleMA(i, g_ExtPeriod, ExtHaLowBuffer);
              }
            else // Recursive calculation
              {
               BufferHiAvg[i] = (BufferHiAvg[i-1] * (g_ExtPeriod - 1) + ExtHaHighBuffer[i]) / g_ExtPeriod;
               BufferLoAvg[i] = (BufferLoAvg[i-1] * (g_ExtPeriod - 1) + ExtHaLowBuffer[i]) / g_ExtPeriod;
              }
            break;
         case MODE_LWMA:
            BufferHiAvg[i] = LinearWeightedMA(i, g_ExtPeriod, ExtHaHighBuffer);
            BufferLoAvg[i] = LinearWeightedMA(i, g_ExtPeriod, ExtHaLowBuffer);
            break;
         default: // MODE_SMA
            BufferHiAvg[i] = SimpleMA(i, g_ExtPeriod, ExtHaHighBuffer);
            BufferLoAvg[i] = SimpleMA(i, g_ExtPeriod, ExtHaLowBuffer);
            break;
        }

      // --- Determine trend and set the final Gann HiLo value ---
      if(ExtHaCloseBuffer[i] > BufferHiAvg[i-1]) // Trend turns up
         BufferTrend[i] = 1;
      else
         if(ExtHaCloseBuffer[i] < BufferLoAvg[i-1]) // Trend turns down
            BufferTrend[i] = -1;
         else // Trend continues
            BufferTrend[i] = BufferTrend[i-1];

      if(BufferTrend[i] == 1)
        {
         BufferHA_GannHiLo[i] = BufferLoAvg[i];
         BufferColor[i] = 0; // Blue for up trend
        }
      else
        {
         BufferHA_GannHiLo[i] = BufferHiAvg[i];
         BufferColor[i] = 1; // Tomato for down trend
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
