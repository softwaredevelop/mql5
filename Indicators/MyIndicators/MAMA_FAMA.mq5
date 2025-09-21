//+------------------------------------------------------------------+
//|                                                    MAMA_FAMA.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.00"
#property description "MESA Adaptive Moving Average (MAMA) and FAMA by John Ehlers."
#property description "Based on the official MotiveWave pseudo-code."

#property indicator_chart_window
#property indicator_buffers 2 // MAMA and FAMA
#property indicator_plots   2

#include <MyIncludes\MESA_Calculator.mqh>

//--- Plot 1: MAMA Line
#property indicator_label1  "MAMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: FAMA Line
#property indicator_label2  "FAMA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGreen
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Input Parameters ---
input ENUM_APPLIED_PRICE InpSourcePrice = PRICE_CLOSE; // Source Price
input double             InpFastLimit   = 0.5;         // Fast Limit
input double             InpSlowLimit   = 0.05;        // Slow Limit

//--- Indicator Buffers ---
double    BufferMAMA[];
double    BufferFAMA[];
double    BufferPrice[];

//--- Global calculator object ---
CMESACalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMAMA, INDICATOR_DATA);
   SetIndexBuffer(1, BufferFAMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferMAMA, false);
   ArraySetAsSeries(BufferFAMA, false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 10);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 10);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MAMA/FAMA(%.2f, %.2f)", InpFastLimit, InpSlowLimit));

   g_calculator = new CMESACalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpFastLimit, InpSlowLimit))
     {
      Print("Failed to initialize MESA Calculator.");
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function.                             |
//+------------------------------------------------------------------+
int OnCalculate(const int, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   int rates_total = ArraySize(close);
   ArrayResize(BufferPrice, rates_total);
   if(PriceSeries(InpSourcePrice, rates_total, open, high, low, close, BufferPrice) <= 0)
      return 0;

   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      g_calculator.Calculate(rates_total, BufferPrice, BufferMAMA, BufferFAMA);
     }
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Helper function to get the selected price series.                |
//+------------------------------------------------------------------+
int PriceSeries(ENUM_APPLIED_PRICE type, int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &dest_buffer[])
  {
   switch(type)
     {
      case PRICE_CLOSE:
         ArrayCopy(dest_buffer, close, 0, 0, rates_total);
         break;
      case PRICE_OPEN:
         ArrayCopy(dest_buffer, open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(dest_buffer, high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(dest_buffer, low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            dest_buffer[i] = (high[i]+low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            dest_buffer[i] = (high[i]+low[i]+close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            dest_buffer[i] = (high[i]+low[i]+close[i]+close[i])/4.0;
         break;
      default:
         return 0;
     }
   return rates_total;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
