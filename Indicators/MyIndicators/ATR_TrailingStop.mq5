//+------------------------------------------------------------------+
//|                                           ATR_TrailingStop.mq5   |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "3.00" // Final version using robust, staged calculation
#property description "ATR Trailing Stop (Chandelier Exit) using Wilder's ATR"

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 6 // Main, Color, ATR, Long, Short, Trend
#property indicator_plots   1

//--- Plot 1: ATR Trailing Stop line
#property indicator_label1  "ATR Trailing Stop"
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
double    BufferATR[];
double    BufferLongStop[];
double    BufferShortStop[];
double    BufferTrend[];

//--- Global Variables ---
int       g_ExtAtrPeriod;
double    g_ExtMultiplier;

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
   SetIndexBuffer(2, BufferATR,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferLongStop,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferShortStop, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferTrend,     INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferStopLine,  false);
   ArraySetAsSeries(BufferColor,     false);
   ArraySetAsSeries(BufferATR,       false);
   ArraySetAsSeries(BufferLongStop,  false);
   ArraySetAsSeries(BufferShortStop, false);
   ArraySetAsSeries(BufferTrend,     false);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtAtrPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ATR Stop(%d, %.1f)", g_ExtAtrPeriod, g_ExtMultiplier));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| ATR Trailing Stop calculation function.                          |
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

//--- STEP 1: Calculate True Range
   double tr[];
   ArrayResize(tr, rates_total);
   for(int i = 1; i < rates_total; i++)
     {
      tr[i] = MathMax(high[i], close[i-1]) - MathMin(low[i], close[i-1]);
     }

//--- STEP 2: Calculate ATR (Wilder's Smoothing)
   for(int i = g_ExtAtrPeriod; i < rates_total; i++)
     {
      if(i == g_ExtAtrPeriod) // Initialization with a simple average of TR
        {
         double atr_sum = 0;
         for(int j = 1; j <= g_ExtAtrPeriod; j++)
            atr_sum += tr[j];
         BufferATR[i] = atr_sum / g_ExtAtrPeriod;
        }
      else // Recursive calculation
        {
         BufferATR[i] = (BufferATR[i-1] * (g_ExtAtrPeriod - 1) + tr[i]) / g_ExtAtrPeriod;
        }
     }

//--- STEP 3: Calculate Raw Stop Levels
   for(int i = g_ExtAtrPeriod -1; i < rates_total; i++)
     {
      BufferLongStop[i]  = Highest(high, g_ExtAtrPeriod, i) - g_ExtMultiplier * BufferATR[i];
      BufferShortStop[i] = Lowest(low, g_ExtAtrPeriod, i) + g_ExtMultiplier * BufferATR[i];
     }

//--- STEP 4: Determine Trend and Final Stop Line
   for(int i = g_ExtAtrPeriod; i < rates_total; i++)
     {
      // Determine trend direction
      if(i == g_ExtAtrPeriod) // Initialization
        {
         if(close[i] > close[i-1])
            BufferTrend[i] = 1;
         else
            BufferTrend[i] = -1;
        }
      else
        {
         if(close[i] > BufferShortStop[i-1])
            BufferTrend[i] = 1;
         else
            if(close[i] < BufferLongStop[i-1])
               BufferTrend[i] = -1;
            else
               BufferTrend[i] = BufferTrend[i-1];
        }

      // Set the final Stop Line value and color
      if(BufferTrend[i] == 1)
        {
         // Trailing logic: stop can only go up or stay
         if(BufferLongStop[i] > BufferStopLine[i-1] || BufferTrend[i-1] == -1)
            BufferStopLine[i] = BufferLongStop[i];
         else
            BufferStopLine[i] = BufferStopLine[i-1];

         BufferColor[i] = 0; // Blue
        }
      else // Trend is -1
        {
         // Trailing logic: stop can only go down or stay
         if(BufferShortStop[i] < BufferStopLine[i-1] || BufferStopLine[i-1] == 0 || BufferTrend[i-1] == 1)
            BufferStopLine[i] = BufferShortStop[i];
         else
            BufferStopLine[i] = BufferStopLine[i-1];

         BufferColor[i] = 1; // Tomato
        }

      // Connect lines on trend change
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
