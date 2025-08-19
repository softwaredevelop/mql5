//+------------------------------------------------------------------+
//|                                 Supertrend_HeikinAshi_Pure.mq5   |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "3.00" // Pure Heikin Ashi version with manual ATR
#property description "Supertrend Indicator based entirely on Heikin Ashi data"

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MovingAverages.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 6 // Supertrend, Color, HA_ATR, Upper, Lower, Trend
#property indicator_plots   1

//--- Plot 1: Supertrend line
#property indicator_label1  "HA_Supertrend_Pure"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLimeGreen, clrTomato
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int    InpAtrPeriod = 10;
input double InpFactor    = 3.0;

//--- Indicator Buffers ---
double    BufferSupertrend[];
double    BufferColor[];
double    BufferHA_ATR[];
double    BufferUpperBand[];
double    BufferLowerBand[];
double    BufferTrend[];

//--- Intermediate Heikin Ashi Buffers ---
double    ExtHaOpenBuffer[];
double    ExtHaHighBuffer[];
double    ExtHaLowBuffer[];
double    ExtHaCloseBuffer[];

//--- Global Objects and Variables ---
int                       g_ExtAtrPeriod;
double                    g_ExtFactor;
CHeikinAshi_Calculator   *g_ha_calculator; // Pointer to our Heikin Ashi calculator

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtAtrPeriod = (InpAtrPeriod < 1) ? 1 : InpAtrPeriod;
   g_ExtFactor    = (InpFactor <= 0) ? 3.0 : InpFactor;

   SetIndexBuffer(0, BufferSupertrend, INDICATOR_DATA);
   SetIndexBuffer(1, BufferColor,      INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferHA_ATR,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferUpperBand,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferLowerBand,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferTrend,      INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferSupertrend, false);
   ArraySetAsSeries(BufferColor,      false);
   ArraySetAsSeries(BufferHA_ATR,     false);
   ArraySetAsSeries(BufferUpperBand,  false);
   ArraySetAsSeries(BufferLowerBand,  false);
   ArraySetAsSeries(BufferTrend,      false);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtAtrPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_Supertrend_Pure(%d, %.1f)", g_ExtAtrPeriod, g_ExtFactor));

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
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
      delete g_ha_calculator;
  }

//+------------------------------------------------------------------+
//| Supertrend on Heikin Ashi calculation function.                  |
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
   if(rates_total <= g_ExtAtrPeriod)
      return(0);

//--- Resize intermediate buffers
   ArrayResize(ExtHaOpenBuffer, rates_total);
   ArrayResize(ExtHaHighBuffer, rates_total);
   ArrayResize(ExtHaLowBuffer, rates_total);
   ArrayResize(ExtHaCloseBuffer, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close,
                             ExtHaOpenBuffer, ExtHaHighBuffer, ExtHaLowBuffer, ExtHaCloseBuffer);

//--- STEP 2: Calculate Heikin Ashi True Range
   double ha_tr[];
   ArrayResize(ha_tr, rates_total);
   for(int i = 1; i < rates_total; i++)
     {
      ha_tr[i] = MathMax(ExtHaHighBuffer[i], ExtHaCloseBuffer[i-1]) - MathMin(ExtHaLowBuffer[i], ExtHaCloseBuffer[i-1]);
     }

//--- STEP 3: Calculate Heikin Ashi ATR and Supertrend in a single loop
   for(int i = 1; i < rates_total; i++)
     {
      // --- Calculate Heikin Ashi ATR (using Wilder's smoothing) ---
      if(i == g_ExtAtrPeriod) // Initialization with SMA
        {
         BufferHA_ATR[i] = SimpleMA(i, g_ExtAtrPeriod, ha_tr);
        }
      else
         if(i > g_ExtAtrPeriod) // Recursive calculation
           {
            BufferHA_ATR[i] = (BufferHA_ATR[i-1] * (g_ExtAtrPeriod - 1) + ha_tr[i]) / g_ExtAtrPeriod;
           }

      // --- Calculate Supertrend Bands and Trend ---
      if(i >= g_ExtAtrPeriod)
        {
         double ha_hl2 = (ExtHaHighBuffer[i] + ExtHaLowBuffer[i]) / 2.0;
         double atr_val = g_ExtFactor * BufferHA_ATR[i];

         double upper_basic = ha_hl2 + atr_val;
         double lower_basic = ha_hl2 - atr_val;

         if(upper_basic < BufferUpperBand[i-1] || ExtHaCloseBuffer[i-1] > BufferUpperBand[i-1])
            BufferUpperBand[i] = upper_basic;
         else
            BufferUpperBand[i] = BufferUpperBand[i-1];

         if(lower_basic > BufferLowerBand[i-1] || ExtHaCloseBuffer[i-1] < BufferLowerBand[i-1])
            BufferLowerBand[i] = lower_basic;
         else
            BufferLowerBand[i] = BufferLowerBand[i-1];

         if(i == g_ExtAtrPeriod)
           {
            if(ExtHaCloseBuffer[i] > ha_hl2)
               BufferTrend[i] = 1;
            else
               BufferTrend[i] = -1;
           }
         else
           {
            if(BufferTrend[i-1] == 1 && ExtHaCloseBuffer[i] < BufferLowerBand[i])
               BufferTrend[i] = -1;
            else
               if(BufferTrend[i-1] == -1 && ExtHaCloseBuffer[i] > BufferUpperBand[i])
                  BufferTrend[i] = 1;
               else
                  BufferTrend[i] = BufferTrend[i-1];
           }

         if(BufferTrend[i] == 1)
           {
            BufferSupertrend[i] = BufferLowerBand[i];
            BufferColor[i] = 0;
            if(BufferTrend[i-1] == -1)
               BufferSupertrend[i-1] = BufferLowerBand[i];
           }
         else
           {
            BufferSupertrend[i] = BufferUpperBand[i];
            BufferColor[i] = 1;
            if(BufferTrend[i-1] == 1)
               BufferSupertrend[i-1] = BufferUpperBand[i];
           }
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
