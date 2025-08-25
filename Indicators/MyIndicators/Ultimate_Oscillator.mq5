//+------------------------------------------------------------------+
//|                                          Ultimate_Oscillator.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Ultimate Oscillator by Larry Williams"

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_maximum 100.0
#property indicator_minimum 0.0
#property indicator_level1  30.0
#property indicator_level2  50.0
#property indicator_level3  70.0
#property indicator_levelstyle STYLE_DOT

//--- Input Parameters ---
input int InpPeriod1 = 7;  // Fast Period
input int InpPeriod2 = 14; // Middle Period
input int InpPeriod3 = 28; // Slow Period

//--- Indicator Buffers ---
double    BufferUO[];

//--- Global Variables ---
int       g_ExtPeriod1, g_ExtPeriod2, g_ExtPeriod3;
const double WEIGHT_1 = 4.0;
const double WEIGHT_2 = 2.0;
const double WEIGHT_3 = 1.0;
const double TOTAL_WEIGHT = WEIGHT_1 + WEIGHT_2 + WEIGHT_3;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtPeriod1 = (InpPeriod1 < 1) ? 1 : InpPeriod1;
   g_ExtPeriod2 = (InpPeriod2 < 1) ? 1 : InpPeriod2;
   g_ExtPeriod3 = (InpPeriod3 < 1) ? 1 : InpPeriod3;

   SetIndexBuffer(0, BufferUO, INDICATOR_DATA);
   ArraySetAsSeries(BufferUO, false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtPeriod3);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("UO(%d,%d,%d)", g_ExtPeriod1, g_ExtPeriod2, g_ExtPeriod3));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Ultimate Oscillator calculation function.                        |
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
   if(rates_total <= g_ExtPeriod3)
      return(0);

//--- STEP 1, 2, 3: Calculate Buying Pressure (BP) and True Range (TR)
   double bp[], tr[];
   ArrayResize(bp, rates_total);
   ArrayResize(tr, rates_total);
   for(int i=1; i<rates_total; i++)
     {
      double true_low = MathMin(low[i], close[i-1]);
      bp[i] = close[i] - true_low;
      tr[i] = MathMax(high[i], close[i-1]) - true_low;
     }

//--- STEP 4, 5, 6: Calculate sums, averages, and final UO
   double sum_bp1=0, sum_tr1=0;
   double sum_bp2=0, sum_tr2=0;
   double sum_bp3=0, sum_tr3=0;

   for(int i = 1; i < rates_total; i++)
     {
      sum_bp1 += bp[i];
      sum_tr1 += tr[i];
      sum_bp2 += bp[i];
      sum_tr2 += tr[i];
      sum_bp3 += bp[i];
      sum_tr3 += tr[i];

      if(i > g_ExtPeriod1)
        {
         sum_bp1 -= bp[i - g_ExtPeriod1];
         sum_tr1 -= tr[i - g_ExtPeriod1];
        }
      if(i > g_ExtPeriod2)
        {
         sum_bp2 -= bp[i - g_ExtPeriod2];
         sum_tr2 -= tr[i - g_ExtPeriod2];
        }
      if(i > g_ExtPeriod3)
        {
         sum_bp3 -= bp[i - g_ExtPeriod3];
         sum_tr3 -= tr[i - g_ExtPeriod3];
        }

      if(i >= g_ExtPeriod3)
        {
         double avg1 = (sum_tr1 > 0) ? sum_bp1 / sum_tr1 : 0;
         double avg2 = (sum_tr2 > 0) ? sum_bp2 / sum_tr2 : 0;
         double avg3 = (sum_tr3 > 0) ? sum_bp3 / sum_tr3 : 0;

         BufferUO[i] = 100.0 * (WEIGHT_1 * avg1 + WEIGHT_2 * avg2 + WEIGHT_3 * avg3) / TOTAL_WEIGHT;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
