//+------------------------------------------------------------------+
//|                                   ATR_TrailingStop_HeikinAshi.mq5|
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "ATR Trailing Stop (Chandelier Exit) on Heikin Ashi data"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 6 // Main, Color, ATR, Long, Short, Trend
#property indicator_plots   1

//--- Plot 1: ATR Trailing Stop line
#property indicator_label1  "HA ATR Trailing Stop"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrDodgerBlue, clrTomato
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int    InpAtrPeriod  = 22;   // ATR Period
input double InpMultiplier = 3.0;  // ATR Multiplier

//--- Indicator Buffers ---
double    BufferStopLine[];
double    BufferColor[];
double    BufferHA_ATR[];
double    BufferLongStop[];
double    BufferShortStop[];
double    BufferTrend[];

//--- Global Objects and Variables ---
int                       g_ExtAtrPeriod;
double                    g_ExtMultiplier;
CHeikinAshi_Calculator   *g_ha_calculator;

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtAtrPeriod  = (InpAtrPeriod < 1) ? 1 : InpAtrPeriod;
   g_ExtMultiplier = (InpMultiplier <= 0) ? 3.0 : InpMultiplier;

   SetIndexBuffer(0, BufferStopLine,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferColor,     INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferHA_ATR,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferLongStop,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferShortStop, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferTrend,     INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferStopLine,  false);
   ArraySetAsSeries(BufferColor,     false);
   ArraySetAsSeries(BufferHA_ATR,    false);
   ArraySetAsSeries(BufferLongStop,  false);
   ArraySetAsSeries(BufferShortStop, false);
   ArraySetAsSeries(BufferTrend,     false);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtAtrPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA ATR Stop(%d, %.1f)", g_ExtAtrPeriod, g_ExtMultiplier));

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
//| ATR Trailing Stop on Heikin Ashi calculation function.           |
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

//--- Intermediate Heikin Ashi Buffers
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- STEP 2: Calculate Heikin Ashi True Range
   double ha_tr[];
   ArrayResize(ha_tr, rates_total);
   for(int i = 1; i < rates_total; i++)
     {
      ha_tr[i] = MathMax(ha_high[i], ha_close[i-1]) - MathMin(ha_low[i], ha_close[i-1]);
     }

//--- STEP 3: Calculate ATR and Trailing Stop in staged loops
// --- 3a: Calculate Heikin Ashi ATR ---
   for(int i = g_ExtAtrPeriod; i < rates_total; i++)
     {
      if(i == g_ExtAtrPeriod)
        {
         double atr_sum = 0;
         for(int j = 1; j <= g_ExtAtrPeriod; j++)
            atr_sum += ha_tr[j];
         BufferHA_ATR[i] = atr_sum / g_ExtAtrPeriod;
        }
      else
        {
         BufferHA_ATR[i] = (BufferHA_ATR[i-1] * (g_ExtAtrPeriod - 1) + ha_tr[i]) / g_ExtAtrPeriod;
        }
     }

// --- 3b: Calculate Raw Stop Levels from HA data ---
   for(int i = g_ExtAtrPeriod -1; i < rates_total; i++)
     {
      BufferLongStop[i]  = Highest(ha_high, g_ExtAtrPeriod, i) - g_ExtMultiplier * BufferHA_ATR[i];
      BufferShortStop[i] = Lowest(ha_low, g_ExtAtrPeriod, i) + g_ExtMultiplier * BufferHA_ATR[i];
     }

// --- 3c: Determine Trend and Final Stop Line ---
   for(int i = g_ExtAtrPeriod; i < rates_total; i++)
     {
      if(i == g_ExtAtrPeriod)
        {
         if(ha_close[i] > ha_close[i-1])
            BufferTrend[i] = 1;
         else
            BufferTrend[i] = -1;
        }
      else
        {
         if(ha_close[i] > BufferShortStop[i-1])
            BufferTrend[i] = 1;
         else
            if(ha_close[i] < BufferLongStop[i-1])
               BufferTrend[i] = -1;
            else
               BufferTrend[i] = BufferTrend[i-1];
        }

      if(BufferTrend[i] == 1)
        {
         if(BufferLongStop[i] > BufferStopLine[i-1] || BufferTrend[i-1] == -1)
            BufferStopLine[i] = BufferLongStop[i];
         else
            BufferStopLine[i] = BufferStopLine[i-1];
         BufferColor[i] = 0;
        }
      else
        {
         if(BufferShortStop[i] < BufferStopLine[i-1] || BufferStopLine[i-1] == 0 || BufferTrend[i-1] == 1)
            BufferStopLine[i] = BufferShortStop[i];
         else
            BufferStopLine[i] = BufferStopLine[i-1];
         BufferColor[i] = 1;
        }

      if(BufferTrend[i] != BufferTrend[i-1])
        {
         if(BufferTrend[i] == 1)
            BufferStopLine[i-1] = BufferLongStop[i];
         else
            BufferStopLine[i-1] = BufferShortStop[i];
        }
     }
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Finds the highest value in a given period of an array.           |
//+------------------------------------------------------------------+
double Highest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      if(res < array[current_pos - i])
         res = array[current_pos - i];
     }
   return(res);
  }

//+------------------------------------------------------------------+
//| Finds the lowest value in a given period of an array.            |
//+------------------------------------------------------------------+
double Lowest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      if(res > array[current_pos - i])
         res = array[current_pos - i];
     }
   return(res);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
