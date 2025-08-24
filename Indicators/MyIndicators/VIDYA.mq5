//+------------------------------------------------------------------+
//|                                                        VIDYA.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Variable Index Dynamic Average by Tushar Chande"

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label1  "VIDYA"

//--- Input Parameters ---
input int                InpPeriodCMO    = 9;       // Chande Momentum Oscillator Period
input int                InpPeriodEMA    = 12;      // EMA Period for smoothing
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // Applied Price

//--- Indicator Buffers ---
double    BufferVIDYA[];

//--- Global Variables ---
int       g_ExtPeriodCMO;
int       g_ExtPeriodEMA;

//--- Forward declarations ---
double CalculateCMO(int position, int period, const double &price_array[]);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtPeriodCMO = (InpPeriodCMO < 1) ? 1 : InpPeriodCMO;
   g_ExtPeriodEMA = (InpPeriodEMA < 1) ? 1 : InpPeriodEMA;

   SetIndexBuffer(0, BufferVIDYA, INDICATOR_DATA);
   ArraySetAsSeries(BufferVIDYA, false);

   int draw_begin = g_ExtPeriodCMO + g_ExtPeriodEMA;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("VIDYA(%d,%d)", g_ExtPeriodCMO, g_ExtPeriodEMA));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Variable Index Dynamic Average calculation function.             |
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
   int start_pos = g_ExtPeriodCMO + g_ExtPeriodEMA;
   if(rates_total <= start_pos)
      return(0);

//--- STEP 1: Prepare the source price array
   double price_source[];
   ArrayResize(price_source, rates_total);
   for(int i=0; i<rates_total; i++)
     {
      switch(InpAppliedPrice)
        {
         case PRICE_OPEN:
            price_source[i] = open[i];
            break;
         case PRICE_HIGH:
            price_source[i] = high[i];
            break;
         case PRICE_LOW:
            price_source[i] = low[i];
            break;
         case PRICE_MEDIAN:
            price_source[i] = (high[i] + low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            price_source[i] = (high[i] + low[i] + close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            price_source[i]= (high[i] + low[i] + 2*close[i]) / 4.0;
            break;
         default:
            price_source[i] = close[i];
            break;
        }
     }

//--- STEP 2: Main calculation loop
   double alpha = 2.0 / (g_ExtPeriodEMA + 1.0);

   for(int i = 1; i < rates_total; i++)
     {
      // --- Initialization Step with SMA ---
      if(i == start_pos)
        {
         double sum = 0;
         for(int j=0; j<g_ExtPeriodEMA; j++)
           {
            sum += price_source[i-j];
           }
         BufferVIDYA[i] = sum / g_ExtPeriodEMA;
         continue;
        }

      if(i > start_pos)
        {
         // --- Recursive Calculation Step ---
         double cmo = MathAbs(CalculateCMO(i, g_ExtPeriodCMO, price_source));
         BufferVIDYA[i] = price_source[i] * alpha * cmo + BufferVIDYA[i-1] * (1 - alpha * cmo);
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Calculates Chande Momentum Oscillator (CMO) for a given position |
//+------------------------------------------------------------------+
double CalculateCMO(int position, int period, const double &price_array[])
  {
   if(position < period)
      return 0.0;

   double sum_up = 0.0;
   double sum_down = 0.0;

   for(int i = 0; i < period; i++)
     {
      double diff = price_array[position - i] - price_array[position - i - 1];
      if(diff > 0.0)
         sum_up += diff;
      else
         sum_down += (-diff);
     }

   if(sum_up + sum_down == 0.0)
      return 0.0;

   return (sum_up - sum_down) / (sum_up + sum_down);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
