//+------------------------------------------------------------------+
//|                                                         MACD.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "6.00" // TradingView style: MACD Line, Signal Line, and Histogram
#property description "Moving Average Convergence/Divergence (TradingView Style)"

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 5 // Histogram, Signal, MACD Line, FastEMA, SlowEMA
#property indicator_plots   3 // Histogram, MACD Line, Signal Line

//--- Plot 1: MACD Histogram
#property indicator_label1  "Histogram"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1

//--- Plot 2: MACD Line
#property indicator_label2  "MACD"
#property indicator_type2   DRAW_LINE
// --- FIX: Replaced hex code with a standard MQL5 color constant ---
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: Signal Line
#property indicator_label3  "Signal"
#property indicator_type3   DRAW_LINE
// --- FIX: Replaced hex code with a standard MQL5 color constant ---
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Input Parameters ---
input int                InpFastEMA      = 12;
input int                InpSlowEMA      = 26;
input int                InpSignalEMA    = 9;
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE;

//--- Indicator Buffers ---
double    BufferMACD_Histogram[]; // Plot 1
double    BufferMACDLine[];       // Plot 2
double    BufferSignalLine[];     // Plot 3
double    BufferFastEMA[];        // Calculation
double    BufferSlowEMA[];        // Calculation

//--- Global Variables ---
int       g_ExtFastEMA, g_ExtSlowEMA, g_ExtSignalEMA;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtFastEMA   = (InpFastEMA < 1) ? 1 : InpFastEMA;
   g_ExtSlowEMA   = (InpSlowEMA < 1) ? 1 : InpSlowEMA;
   g_ExtSignalEMA = (InpSignalEMA < 1) ? 1 : InpSignalEMA;

   if(g_ExtFastEMA > g_ExtSlowEMA)
     {
      int temp = g_ExtFastEMA;
      g_ExtFastEMA = g_ExtSlowEMA;
      g_ExtSlowEMA = temp;
     }

   SetIndexBuffer(0, BufferMACD_Histogram, INDICATOR_DATA);
   SetIndexBuffer(1, BufferMACDLine,       INDICATOR_DATA);
   SetIndexBuffer(2, BufferSignalLine,     INDICATOR_DATA);
   SetIndexBuffer(3, BufferFastEMA,        INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferSlowEMA,        INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferMACD_Histogram, false);
   ArraySetAsSeries(BufferMACDLine,       false);
   ArraySetAsSeries(BufferSignalLine,     false);
   ArraySetAsSeries(BufferFastEMA,        false);
   ArraySetAsSeries(BufferSlowEMA,        false);

   int macd_line_draw_begin = g_ExtSlowEMA - 1;
   int signal_draw_begin = g_ExtSlowEMA + g_ExtSignalEMA - 2;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, signal_draw_begin); // Histogram
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, macd_line_draw_begin); // MACD Line
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, signal_draw_begin); // Signal Line

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MACD(%d,%d,%d)", g_ExtFastEMA, g_ExtSlowEMA, g_ExtSignalEMA));
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
   int start_pos = g_ExtSlowEMA + g_ExtSignalEMA - 2;
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

//--- STEP 2: Calculate Fast EMA
   double pr_fast = 2.0 / (g_ExtFastEMA + 1.0);
   for(int i = g_ExtFastEMA - 1; i < rates_total; i++)
     {
      if(i == g_ExtFastEMA - 1)
        {
         double sum = 0;
         for(int j=0; j<g_ExtFastEMA; j++)
            sum += price_source[i-j];
         BufferFastEMA[i] = sum / g_ExtFastEMA;
        }
      else
        {
         BufferFastEMA[i] = price_source[i] * pr_fast + BufferFastEMA[i-1] * (1.0 - pr_fast);
        }
     }

//--- STEP 3: Calculate Slow EMA
   double pr_slow = 2.0 / (g_ExtSlowEMA + 1.0);
   for(int i = g_ExtSlowEMA - 1; i < rates_total; i++)
     {
      if(i == g_ExtSlowEMA - 1)
        {
         double sum = 0;
         for(int j=0; j<g_ExtSlowEMA; j++)
            sum += price_source[i-j];
         BufferSlowEMA[i] = sum / g_ExtSlowEMA;
        }
      else
        {
         BufferSlowEMA[i] = price_source[i] * pr_slow + BufferSlowEMA[i-1] * (1.0 - pr_slow);
        }
     }

//--- STEP 4: Calculate MACD Line
   for(int i = g_ExtSlowEMA - 1; i < rates_total; i++)
     {
      BufferMACDLine[i] = BufferFastEMA[i] - BufferSlowEMA[i];
     }

//--- STEP 5: Calculate Signal Line (EMA of MACD Line) and Histogram
   double pr_signal = 2.0 / (g_ExtSignalEMA + 1.0);
   for(int i = start_pos; i < rates_total; i++)
     {
      if(i == start_pos)
        {
         double sum = 0;
         for(int j=0; j<g_ExtSignalEMA; j++)
            sum += BufferMACDLine[i-j];
         BufferSignalLine[i] = sum / g_ExtSignalEMA;
        }
      else
        {
         BufferSignalLine[i] = BufferMACDLine[i] * pr_signal + BufferSignalLine[i-1] * (1.0 - pr_signal);
        }

      BufferMACD_Histogram[i] = BufferMACDLine[i] - BufferSignalLine[i];
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
