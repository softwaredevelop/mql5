//+------------------------------------------------------------------+
//|                                                          HMA.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "3.00" // Fully manual, self-contained, and accurate
#property description "Hull Moving Average (HMA)"

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 4 // HMA, and 3 calculation buffers
#property indicator_plots   1

//--- Plot 1: HMA line
#property indicator_label1  "HMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepPink
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int                InpPeriodHMA    = 14;
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE;

//--- Indicator Buffers ---
double    BufferHMA[];
double    BufferWMA_Half[];
double    BufferWMA_Full[];
double    BufferRawHMA[];

//--- Global Variables ---
int       g_ExtPeriodHMA;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtPeriodHMA = (InpPeriodHMA < 1) ? 1 : InpPeriodHMA;

   SetIndexBuffer(0, BufferHMA,      INDICATOR_DATA);
   SetIndexBuffer(1, BufferWMA_Half, INDICATOR_CALCULATIONS);
   SetIndexBuffer(2, BufferWMA_Full, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferRawHMA,   INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferHMA,      false);
   ArraySetAsSeries(BufferWMA_Half, false);
   ArraySetAsSeries(BufferWMA_Full, false);
   ArraySetAsSeries(BufferRawHMA,   false);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtPeriodHMA + (int)MathFloor(MathSqrt(g_ExtPeriodHMA)) - 2);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HMA(%d)", g_ExtPeriodHMA));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Hull Moving Average calculation function.                        |
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
   int start_pos = g_ExtPeriodHMA + (int)MathFloor(MathSqrt(g_ExtPeriodHMA)) - 2;
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

//--- STEP 2: Calculate all HMA components
   int period_half = (int)MathMax(1, MathRound(g_ExtPeriodHMA / 2.0));
   int period_sqrt = (int)MathMax(1, MathRound(MathSqrt(g_ExtPeriodHMA)));

// --- First Pass: Calculate base WMAs and Raw HMA ---
   for(int i = g_ExtPeriodHMA - 1; i < rates_total; i++)
     {
      // Manual WMA for half period
      double lwma_sum_half = 0;
      double weight_sum_half = 0;
      for(int j=0; j<period_half; j++)
        {
         int weight = period_half - j;
         lwma_sum_half += price_source[i-j] * weight;
         weight_sum_half += weight;
        }
      if(weight_sum_half > 0)
         BufferWMA_Half[i] = lwma_sum_half / weight_sum_half;

      // Manual WMA for full period
      double lwma_sum_full = 0;
      double weight_sum_full = 0;
      for(int j=0; j<g_ExtPeriodHMA; j++)
        {
         int weight = g_ExtPeriodHMA - j;
         lwma_sum_full += price_source[i-j] * weight;
         weight_sum_full += weight;
        }
      if(weight_sum_full > 0)
         BufferWMA_Full[i] = lwma_sum_full / weight_sum_full;

      // Calculate Raw HMA
      BufferRawHMA[i] = 2 * BufferWMA_Half[i] - BufferWMA_Full[i];
     }

// --- Second Pass: Calculate final HMA ---
   for(int i = start_pos; i < rates_total; i++)
     {
      // Manual WMA for sqrt period on Raw HMA data
      double lwma_sum_sqrt = 0;
      double weight_sum_sqrt = 0;
      for(int j=0; j<period_sqrt; j++)
        {
         int weight = period_sqrt - j;
         lwma_sum_sqrt += BufferRawHMA[i-j] * weight;
         weight_sum_sqrt += weight;
        }
      if(weight_sum_sqrt > 0)
         BufferHMA[i] = lwma_sum_sqrt / weight_sum_sqrt;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
