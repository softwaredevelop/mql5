//+------------------------------------------------------------------+
//|                                               BollingerBands.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Bollinger Bands - a volatility indicator"

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 3 // Upper, Lower, Middle
#property indicator_plots   3

//--- Plot 1: Upper Band
#property indicator_label1  "Upper Band"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_DOT

//--- Plot 2: Lower Band
#property indicator_label2  "Lower Band"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_DOT

//--- Plot 3: Middle Band (Basis)
#property indicator_label3  "Basis"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_style3  STYLE_SOLID

//--- Input Parameters ---
input int                InpBBPeriod     = 20;      // Bollinger Bands Period
input double             InpBBDeviation  = 2.0;     // Deviation
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // Applied Price

//--- Indicator Buffers ---
double    BufferUpper[];
double    BufferLower[];
double    BufferMiddle[];

//--- Global Variables ---
int       g_ExtBBPeriod;
double    g_ExtBBDeviation;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtBBPeriod    = (InpBBPeriod < 1) ? 1 : InpBBPeriod;
   g_ExtBBDeviation = (InpBBDeviation <= 0) ? 2.0 : InpBBDeviation;

   SetIndexBuffer(0, BufferUpper,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferLower,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferMiddle, INDICATOR_DATA);

   ArraySetAsSeries(BufferUpper,  false);
   ArraySetAsSeries(BufferLower,  false);
   ArraySetAsSeries(BufferMiddle, false);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtBBPeriod - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtBBPeriod - 1);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, g_ExtBBPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("BB(%d, %.1f)", g_ExtBBPeriod, g_ExtBBDeviation));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Bollinger Bands calculation function.                            |
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
   if(rates_total < g_ExtBBPeriod)
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
   double sma_sum = 0;
   for(int i = 0; i < rates_total; i++)
     {
      sma_sum += price_source[i];

      if(i >= g_ExtBBPeriod)
        {
         sma_sum -= price_source[i - g_ExtBBPeriod];
        }

      if(i >= g_ExtBBPeriod - 1)
        {
         // --- Calculate Middle Band (SMA) ---
         BufferMiddle[i] = sma_sum / g_ExtBBPeriod;

         // --- Calculate Standard Deviation ---
         double deviation_sum_sq = 0;
         for(int j = 0; j < g_ExtBBPeriod; j++)
           {
            double diff = price_source[i - j] - BufferMiddle[i];
            deviation_sum_sq += diff * diff;
           }
         double std_dev = MathSqrt(deviation_sum_sq / g_ExtBBPeriod);

         // --- Calculate Upper and Lower Bands ---
         double dev_offset = g_ExtBBDeviation * std_dev;
         BufferUpper[i] = BufferMiddle[i] + dev_offset;
         BufferLower[i] = BufferMiddle[i] - dev_offset;
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
