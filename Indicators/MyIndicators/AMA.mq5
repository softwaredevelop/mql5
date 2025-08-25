//+------------------------------------------------------------------+
//|                                                          AMA.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.01" // Corrected standard version
#property description "Adaptive Moving Average (AMA) by Perry Kaufman"

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label1  "AMA"

//--- Input Parameters ---
input int                InpAmaPeriod    = 10;      // AMA Efficiency Ratio Period
input int                InpFastEmaPeriod= 2;       // Fast EMA Period for scaling
input int                InpSlowEmaPeriod= 30;      // Slow EMA Period for scaling
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // Applied Price

//--- Indicator Buffers ---
double    BufferAMA[];

//--- Global Variables ---
int       g_ExtAmaPeriod;
int       g_ExtFastEmaPeriod;
int       g_ExtSlowEmaPeriod;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtAmaPeriod     = (InpAmaPeriod < 1) ? 1 : InpAmaPeriod;
   g_ExtFastEmaPeriod = (InpFastEmaPeriod < 1) ? 1 : InpFastEmaPeriod;
   g_ExtSlowEmaPeriod = (InpSlowEmaPeriod < 1) ? 1 : InpSlowEmaPeriod;

   SetIndexBuffer(0, BufferAMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferAMA, false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtAmaPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("AMA(%d,%d,%d)", g_ExtAmaPeriod, g_ExtFastEmaPeriod, g_ExtSlowEmaPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Adaptive Moving Average calculation function.                    |
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
   if(rates_total <= g_ExtAmaPeriod)
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
   double fast_sc = 2.0 / (g_ExtFastEmaPeriod + 1.0);
   double slow_sc = 2.0 / (g_ExtSlowEmaPeriod + 1.0);

   for(int i = 1; i < rates_total; i++)
     {
      // --- Initialization Step ---
      if(i == g_ExtAmaPeriod)
        {
         // The first AMA value is simply the current price
         BufferAMA[i] = price_source[i];
         continue;
        }

      if(i > g_ExtAmaPeriod)
        {
         // --- Calculate Efficiency Ratio (ER) ---
         double direction = MathAbs(price_source[i] - price_source[i - g_ExtAmaPeriod]);
         double volatility = 0;
         for(int j = 0; j < g_ExtAmaPeriod; j++)
           {
            volatility += MathAbs(price_source[i - j] - price_source[i - j - 1]);
           }
         double er = (volatility > 0) ? direction / volatility : 0;

         // --- Calculate Scaled Smoothing Constant (SSC) ---
         double ssc = er * (fast_sc - slow_sc) + slow_sc;
         double ssc_sq = ssc * ssc;

         // --- Calculate Final AMA ---
         BufferAMA[i] = BufferAMA[i-1] + ssc_sq * (price_source[i] - BufferAMA[i-1]);
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
