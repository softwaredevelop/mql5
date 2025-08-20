//+------------------------------------------------------------------+
//|                                                          ALMA.mq5|
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored to be self-contained and stable
#property description "Arnaud Legoux Moving Average (ALMA)"

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: ALMA line
#property indicator_label1  "ALMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumVioletRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int                InpAlmaPeriod   = 9;       // Window size (period)
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // Applied price
input double             InpAlmaOffset   = 0.85;    // Offset (0 to 1)
input double             InpAlmaSigma    = 6.0;     // Sigma (smoothness)

//--- Indicator Buffers ---
double    BufferALMA[];

//--- Global Variables ---
int       g_ExtAlmaPeriod;
double    g_ExtAlmaOffset;
double    g_ExtAlmaSigma;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate and store input parameters
   g_ExtAlmaPeriod = (InpAlmaPeriod < 1) ? 1 : InpAlmaPeriod;
   g_ExtAlmaOffset = InpAlmaOffset;
   g_ExtAlmaSigma  = (InpAlmaSigma <= 0) ? 0.01 : InpAlmaSigma;

//--- Map the buffer and set as non-timeseries
   SetIndexBuffer(0, BufferALMA,  INDICATOR_DATA);
   ArraySetAsSeries(BufferALMA,  false);

//--- Set indicator display properties
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtAlmaPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ALMA(%d, %.2f, %.1f)", g_ExtAlmaPeriod, g_ExtAlmaOffset, g_ExtAlmaSigma));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Arnaud Legoux Moving Average calculation function.               |
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
   if(rates_total < g_ExtAlmaPeriod)
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
   double m = g_ExtAlmaOffset * (g_ExtAlmaPeriod - 1.0);
   double s = (double)g_ExtAlmaPeriod / g_ExtAlmaSigma;

   for(int i = g_ExtAlmaPeriod - 1; i < rates_total; i++)
     {
      double sum = 0.0;
      double norm = 0.0;

      for(int j = 0; j < g_ExtAlmaPeriod; j++)
        {
         double weight = MathExp(-1 * MathPow(j - m, 2) / (2 * s * s));
         int price_index = i - (g_ExtAlmaPeriod - 1) + j;

         sum += price_source[price_index] * weight;
         norm += weight;
        }

      if(norm > 0)
         BufferALMA[i] = sum / norm;
      else
         BufferALMA[i] = 0.0;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
