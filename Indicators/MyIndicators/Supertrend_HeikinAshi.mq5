//+------------------------------------------------------------------+
//|                                    Supertrend_HeikinAshi.mq5     |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored for full recalculation and stability
#property description "Supertrend Indicator on Heikin Ashi data"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 6 // Supertrend, Color, ATR, Upper, Lower, Trend
#property indicator_plots   1

//--- Plot 1: Supertrend line
#property indicator_label1  "HA_Supertrend"
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
double    BufferATR[];
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
int                       g_handle_atr;
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
   SetIndexBuffer(2, BufferATR,        INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferUpperBand,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferLowerBand,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferTrend,      INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferSupertrend, false);
   ArraySetAsSeries(BufferColor,      false);
   ArraySetAsSeries(BufferATR,        false);
   ArraySetAsSeries(BufferUpperBand,  false);
   ArraySetAsSeries(BufferLowerBand,  false);
   ArraySetAsSeries(BufferTrend,      false);

// ATR is calculated on standard candles for true volatility
   g_handle_atr = iATR(_Symbol, _Period, g_ExtAtrPeriod);
   if(g_handle_atr == INVALID_HANDLE)
     {
      Print("Error creating iATR handle.");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtAtrPeriod);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE); // For trend change gaps
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_Supertrend(%d, %.1f)", g_ExtAtrPeriod, g_ExtFactor));

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
   IndicatorRelease(g_handle_atr);
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

//--- STEP 2: Get ATR values
   if(CopyBuffer(g_handle_atr, 0, 0, rates_total, BufferATR) < rates_total)
     {
      Print("Error copying iATR buffer data.");
     }

//--- STEP 3: Main calculation loop with robust initialization
   for(int i = 1; i < rates_total; i++)
     {
      double ha_hl2 = (ExtHaHighBuffer[i] + ExtHaLowBuffer[i]) / 2.0;
      double atr_val = g_ExtFactor * BufferATR[i];

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
         if(i > g_ExtAtrPeriod)
           {
            if(BufferTrend[i-1] == 1 && ExtHaCloseBuffer[i] < BufferLowerBand[i])
               BufferTrend[i] = -1;
            else
               if(BufferTrend[i-1] == -1 && ExtHaCloseBuffer[i] > BufferUpperBand[i])
                  BufferTrend[i] = 1;
               else
                  BufferTrend[i] = BufferTrend[i-1];
           }

      // --- FIX: Logic for connected lines on trend change ---
      if(BufferTrend[i] == 1) // Uptrend
        {
         BufferSupertrend[i] = BufferLowerBand[i];
         BufferColor[i] = 0;
         // If trend just changed to UP, connect the previous point
         if(BufferTrend[i-1] == -1)
           {
            BufferSupertrend[i-1] = BufferLowerBand[i];
           }
        }
      else // Downtrend
        {
         BufferSupertrend[i] = BufferUpperBand[i];
         BufferColor[i] = 1;
         // If trend just changed to DOWN, connect the previous point
         if(BufferTrend[i-1] == 1)
           {
            BufferSupertrend[i-1] = BufferUpperBand[i];
           }
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
