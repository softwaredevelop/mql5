//+------------------------------------------------------------------+
//|                                              MACD_HeikinAshi.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00" // TradingView style on Heikin Ashi data
#property description "MACD on Heikin Ashi data (TradingView Style)"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 5 // Histogram, MACD Line, Signal Line, FastEMA, SlowEMA
#property indicator_plots   3 // Histogram, MACD Line, Signal Line

//--- Plot 1: MACD Histogram
#property indicator_label1  "HA_Hist"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1

//--- Plot 2: MACD Line
#property indicator_label2  "HA_MACD"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: Signal Line
#property indicator_label3  "HA_Signal"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Enum for selecting Heikin Ashi price source ---
enum ENUM_HA_APPLIED_PRICE
  {
   HA_PRICE_CLOSE, HA_PRICE_OPEN, HA_PRICE_HIGH, HA_PRICE_LOW
  };

//--- Input Parameters ---
input int                   InpFastEMA      = 12;
input int                   InpSlowEMA      = 26;
input int                   InpSignalEMA    = 9;
input ENUM_HA_APPLIED_PRICE InpAppliedPrice = HA_PRICE_CLOSE;

//--- Indicator Buffers ---
double    BufferMACD_Histogram[];
double    BufferMACDLine[];
double    BufferSignalLine[];
double    BufferFastEMA[];
double    BufferSlowEMA[];

//--- Global Objects and Variables ---
int                       g_ExtFastEMA, g_ExtSlowEMA, g_ExtSignalEMA;
CHeikinAshi_Calculator   *g_ha_calculator;

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

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, signal_draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, macd_line_draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, signal_draw_begin);

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_MACD(%d,%d,%d)", g_ExtFastEMA, g_ExtSlowEMA, g_ExtSignalEMA));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   g_ha_calculator = new CHeikinAshi_Calculator();
   if(CheckPointer(g_ha_calculator) == POINTER_INVALID)
     {
      Print("Error creating CHeikinAshi_Calculator object");
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
     {
      delete g_ha_calculator;
      g_ha_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| MACD on Heikin Ashi calculation function.                        |
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

//--- Intermediate Heikin Ashi Buffers
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- STEP 2: Prepare the Heikin Ashi source price array
   double ha_price_source[];
   ArrayResize(ha_price_source, rates_total);
   switch(InpAppliedPrice)
     {
      case HA_PRICE_OPEN:
         ArrayCopy(ha_price_source, ha_open);
         break;
      case HA_PRICE_HIGH:
         ArrayCopy(ha_price_source, ha_high);
         break;
      case HA_PRICE_LOW:
         ArrayCopy(ha_price_source, ha_low);
         break;
      default:
         ArrayCopy(ha_price_source, ha_close);
         break;
     }

//--- STEP 3: Calculate Fast EMA on HA data
   double pr_fast = 2.0 / (g_ExtFastEMA + 1.0);
   for(int i = g_ExtFastEMA - 1; i < rates_total; i++)
     {
      if(i == g_ExtFastEMA - 1)
        {
         double sum = 0;
         for(int j=0; j<g_ExtFastEMA; j++)
            sum += ha_price_source[i-j];
         BufferFastEMA[i] = sum / g_ExtFastEMA;
        }
      else
        {
         BufferFastEMA[i] = ha_price_source[i] * pr_fast + BufferFastEMA[i-1] * (1.0 - pr_fast);
        }
     }

//--- STEP 4: Calculate Slow EMA on HA data
   double pr_slow = 2.0 / (g_ExtSlowEMA + 1.0);
   for(int i = g_ExtSlowEMA - 1; i < rates_total; i++)
     {
      if(i == g_ExtSlowEMA - 1)
        {
         double sum = 0;
         for(int j=0; j<g_ExtSlowEMA; j++)
            sum += ha_price_source[i-j];
         BufferSlowEMA[i] = sum / g_ExtSlowEMA;
        }
      else
        {
         BufferSlowEMA[i] = ha_price_source[i] * pr_slow + BufferSlowEMA[i-1] * (1.0 - pr_slow);
        }
     }

//--- STEP 5: Calculate MACD Line
   for(int i = g_ExtSlowEMA - 1; i < rates_total; i++)
     {
      BufferMACDLine[i] = BufferFastEMA[i] - BufferSlowEMA[i];
     }

//--- STEP 6: Calculate Signal Line (EMA of MACD Line) and Histogram
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
