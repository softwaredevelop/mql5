//+------------------------------------------------------------------+
//|                                          McGinleyDynamic.mq5     |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.01" // Corrected array handling for MQL5 syntax
#property description "McGinley Dynamic Indicator"

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: McGinley Dynamic line
#property indicator_label1  "McGinley"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int                InpLength       = 14;      // Period
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // Applied Price

//--- Indicator Buffers ---
double    BufferMcGinley[];

//--- Global Variables ---
int       g_ExtLength;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate and store input
   g_ExtLength = (InpLength < 1) ? 1 : InpLength;

//--- Map the buffer and set as non-timeseries
   SetIndexBuffer(0, BufferMcGinley, INDICATOR_DATA);
   ArraySetAsSeries(BufferMcGinley, false);

//--- Set indicator display properties
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("McGinley(%d)", g_ExtLength));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| McGinley Dynamic calculation function.                           |
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
   if(rates_total < 2)
      return(0);

//--- STEP 1: Prepare the source price array
   double price_source[];
   ArrayResize(price_source, rates_total);

   switch(InpAppliedPrice)
     {
      case PRICE_OPEN:
         ArrayCopy(price_source, open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(price_source, high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(price_source, low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
      case PRICE_TYPICAL:
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
           {
            switch(InpAppliedPrice)
              {
               case PRICE_MEDIAN:
                  price_source[i] = (high[i] + low[i]) / 2.0;
                  break;
               case PRICE_TYPICAL:
                  price_source[i] = (high[i] + low[i] + close[i]) / 3.0;
                  break;
               case PRICE_WEIGHTED:
                  price_source[i] = (high[i] + low[i] + 2*close[i]) / 4.0;
                  break;
              }
           }
         break;
      default: // PRICE_CLOSE
         ArrayCopy(price_source, close, 0, 0, rates_total);
         break;
     }

//--- STEP 2: Main calculation loop for McGinley Dynamic
   for(int i = 0; i < rates_total; i++)
     {
      // --- Initialization Step ---
      if(i == 0)
        {
         BufferMcGinley[i] = price_source[i];
         continue;
        }

      // --- Recursive Calculation Step ---
      double prev_mg = BufferMcGinley[i-1];

      if(prev_mg == 0)
        {
         BufferMcGinley[i] = price_source[i];
         continue;
        }

      double denominator = g_ExtLength * MathPow(price_source[i] / prev_mg, 4);

      if(denominator == 0)
        {
         BufferMcGinley[i] = prev_mg;
         continue;
        }

      BufferMcGinley[i] = prev_mg + (price_source[i] - prev_mg) / denominator;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
