//+------------------------------------------------------------------+
//|                                                     MACD_Pro.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "8.00" // Final robust version with explicit loops
#property description "MACD with selectable MA types for all components"

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 5 // Histogram, MACD Line, Signal Line, FastMA, SlowMA
#property indicator_plots   3 // Histogram, MACD Line, Signal Line

//--- Plot 1: MACD Histogram
#property indicator_label1  "Histogram"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1

//--- Plot 2: MACD Line
#property indicator_label2  "MACD"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: Signal Line
#property indicator_label3  "Signal"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Input Parameters ---
input int                InpFastPeriod   = 12;
input int                InpSlowPeriod   = 26;
input int                InpSignalPeriod = 9;
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE;
input ENUM_MA_METHOD     InpSourceMAType = MODE_EMA; // MA Type for Fast and Slow lines
input ENUM_MA_METHOD     InpSignalMAType = MODE_EMA; // MA Type for Signal line

//--- Indicator Buffers ---
double    BufferMACD_Histogram[];
double    BufferMACDLine[];
double    BufferSignalLine[];
double    BufferFastMA[];
double    BufferSlowMA[];

//--- Global Variables ---
int       g_ExtFastPeriod, g_ExtSlowPeriod, g_ExtSignalPeriod;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtFastPeriod   = (InpFastPeriod < 1) ? 1 : InpFastPeriod;
   g_ExtSlowPeriod   = (InpSlowPeriod < 1) ? 1 : InpSlowPeriod;
   g_ExtSignalPeriod = (InpSignalPeriod < 1) ? 1 : InpSignalPeriod;

   if(g_ExtFastPeriod > g_ExtSlowPeriod)
     {
      int temp = g_ExtFastPeriod;
      g_ExtFastPeriod = g_ExtSlowPeriod;
      g_ExtSlowPeriod = temp;
     }

   SetIndexBuffer(0, BufferMACD_Histogram, INDICATOR_DATA);
   SetIndexBuffer(1, BufferMACDLine,       INDICATOR_DATA);
   SetIndexBuffer(2, BufferSignalLine,     INDICATOR_DATA);
   SetIndexBuffer(3, BufferFastMA,         INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferSlowMA,         INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferMACD_Histogram, false);
   ArraySetAsSeries(BufferMACDLine,       false);
   ArraySetAsSeries(BufferSignalLine,     false);
   ArraySetAsSeries(BufferFastMA,         false);
   ArraySetAsSeries(BufferSlowMA,         false);

   int macd_line_draw_begin = g_ExtSlowPeriod - 1;
   int signal_draw_begin = g_ExtSlowPeriod + g_ExtSignalPeriod - 2;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, signal_draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, macd_line_draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, signal_draw_begin);

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MACD Pro(%d,%d,%d)", g_ExtFastPeriod, g_ExtSlowPeriod, g_ExtSignalPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Moving Average Convergence/Divergence calculation function.      |
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
   int start_pos = g_ExtSlowPeriod + g_ExtSignalPeriod - 2;
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
         default:
            price_source[i] = close[i];
            break;
        }
     }

//--- STEP 2: Calculate Fast MA
   for(int i = g_ExtFastPeriod - 1; i < rates_total; i++)
     {
      // This switch block calculates the Fast MA
      switch(InpSourceMAType)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == g_ExtFastPeriod - 1)
              {
               double sum=0;
               for(int j=0; j<g_ExtFastPeriod; j++)
                  sum+=price_source[i-j];
               BufferFastMA[i] = sum/g_ExtFastPeriod;
              }
            else
              {
               if(InpSourceMAType == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtFastPeriod+1.0);
                  BufferFastMA[i] = price_source[i]*pr + BufferFastMA[i-1]*(1.0-pr);
                 }
               else
                  BufferFastMA[i] = (BufferFastMA[i-1]*(g_ExtFastPeriod-1)+price_source[i])/g_ExtFastPeriod;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtFastPeriod; j++)
              {
               int weight=g_ExtFastPeriod-j;
               lwma_sum+=price_source[i-j]*weight;
               weight_sum+=weight;
              }
            if(weight_sum>0)
               BufferFastMA[i]=lwma_sum/weight_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<g_ExtFastPeriod; j++)
               sum+=price_source[i-j];
            BufferFastMA[i] = sum/g_ExtFastPeriod;
           }
         break;
        }
     }

//--- STEP 3: Calculate Slow MA
   for(int i = g_ExtSlowPeriod - 1; i < rates_total; i++)
     {
      // This switch block calculates the Slow MA
      switch(InpSourceMAType)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == g_ExtSlowPeriod - 1)
              {
               double sum=0;
               for(int j=0; j<g_ExtSlowPeriod; j++)
                  sum+=price_source[i-j];
               BufferSlowMA[i] = sum/g_ExtSlowPeriod;
              }
            else
              {
               if(InpSourceMAType == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtSlowPeriod+1.0);
                  BufferSlowMA[i] = price_source[i]*pr + BufferSlowMA[i-1]*(1.0-pr);
                 }
               else
                  BufferSlowMA[i] = (BufferSlowMA[i-1]*(g_ExtSlowPeriod-1)+price_source[i])/g_ExtSlowPeriod;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtSlowPeriod; j++)
              {
               int weight=g_ExtSlowPeriod-j;
               lwma_sum+=price_source[i-j]*weight;
               weight_sum+=weight;
              }
            if(weight_sum>0)
               BufferSlowMA[i]=lwma_sum/weight_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<g_ExtSlowPeriod; j++)
               sum+=price_source[i-j];
            BufferSlowMA[i] = sum/g_ExtSlowPeriod;
           }
         break;
        }
     }

//--- STEP 4: Calculate MACD Line
   for(int i = g_ExtSlowPeriod - 1; i < rates_total; i++)
     {
      BufferMACDLine[i] = BufferFastMA[i] - BufferSlowMA[i];
     }

//--- STEP 5: Calculate Signal Line and Histogram
   for(int i = start_pos; i < rates_total; i++)
     {
      // This switch block calculates the Signal Line on the MACD Line
      switch(InpSignalMAType)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == start_pos)
              {
               double sum=0;
               for(int j=0; j<g_ExtSignalPeriod; j++)
                  sum+=BufferMACDLine[i-j];
               BufferSignalLine[i] = sum/g_ExtSignalPeriod;
              }
            else
              {
               if(InpSignalMAType == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtSignalPeriod+1.0);
                  BufferSignalLine[i] = BufferMACDLine[i]*pr + BufferSignalLine[i-1]*(1.0-pr);
                 }
               else
                  BufferSignalLine[i] = (BufferSignalLine[i-1]*(g_ExtSignalPeriod-1)+BufferMACDLine[i])/g_ExtSignalPeriod;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtSignalPeriod; j++)
              {
               int weight=g_ExtSignalPeriod-j;
               lwma_sum+=BufferMACDLine[i-j]*weight;
               weight_sum+=weight;
              }
            if(weight_sum>0)
               BufferSignalLine[i]=lwma_sum/weight_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<g_ExtSignalPeriod; j++)
               sum+=BufferMACDLine[i-j];
            BufferSignalLine[i] = sum/g_ExtSignalPeriod;
           }
         break;
        }

      BufferMACD_Histogram[i] = BufferMACDLine[i] - BufferSignalLine[i];
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
