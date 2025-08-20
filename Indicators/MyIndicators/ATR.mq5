//+------------------------------------------------------------------+
//|                                                          ATR.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Average True Range"

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: ATR line
#property indicator_label1  "ATR"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Input Parameters ---
input int InpAtrPeriod = 14; // ATR Period

//--- Indicator Buffers ---
double    BufferATR[];

//--- Global Variables ---
int       g_ExtAtrPeriod;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtAtrPeriod = (InpAtrPeriod < 1) ? 1 : InpAtrPeriod;

   SetIndexBuffer(0, BufferATR, INDICATOR_DATA);
   ArraySetAsSeries(BufferATR, false);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtAtrPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ATR(%d)", g_ExtAtrPeriod));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Average True Range calculation function.                         |
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
      double range1 = high[i] - low[i];
      double range2 = MathAbs(high[i] - close[i-1]);
      double range3 = MathAbs(low[i] - close[i-1]);
      tr[i] = MathMax(range1, MathMax(range2, range3));
     }

//--- STEP 2: Calculate ATR (Wilder's Smoothing)
   for(int i = 1; i < rates_total; i++)
     {
      if(i == g_ExtAtrPeriod) // Initialization with a simple average of TR
        {
         double sum_tr = 0;
         for(int j = 1; j <= g_ExtAtrPeriod; j++)
           {
            sum_tr += tr[j];
           }
         BufferATR[i] = sum_tr / g_ExtAtrPeriod;
        }
      else
         if(i > g_ExtAtrPeriod) // Recursive calculation
           {
            BufferATR[i] = (BufferATR[i-1] * (g_ExtAtrPeriod - 1) + tr[i]) / g_ExtAtrPeriod;
           }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
