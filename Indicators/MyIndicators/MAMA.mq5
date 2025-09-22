//+------------------------------------------------------------------+
//|                                                         MAMA.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.01"
#property description "MESA Adaptive Moving Average (MAMA) by John Ehlers. Clean implementation."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

#include <MyIncludes\MESA_Calculator.mqh>

//--- Plot 1: MAMA Line
#property indicator_label1  "MAMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input ENUM_APPLIED_PRICE InpSourcePrice = PRICE_CLOSE; // Source Price
input double             InpFastLimit   = 0.5;         // Fast Limit
input double             InpSlowLimit   = 0.05;        // Slow Limit

//--- Indicator Buffers ---
double    BufferMAMA[];
double    BufferPrice[];

//--- Global calculator object ---
CMESACalculator *g_calculator;

//--- Forward declaration
int PriceSeries(ENUM_APPLIED_PRICE,int,const double&[],const double&[],const double&[],const double&[],double&[]);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMAMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferMAMA, false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 10);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MAMA(%.2f, %.2f)", InpFastLimit, InpSlowLimit));

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
   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      //--- Corrected: Pass all required parameters to the Calculate method
      double dummy_fama[];
      g_calculator.Calculate(rates_total, InpSourcePrice, open, high, low, close, BufferMAMA, dummy_fama);
     }
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Helper function to get the selected price series.                |
//+------------------------------------------------------------------+
int PriceSeries(ENUM_APPLIED_PRICE type, int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &dest_buffer[])
  {
// This helper is not strictly needed anymore as logic is in the calculator,
// but we keep it for potential future use or consistency.
// The main indicator now passes the raw OHLC to the calculator.
   return rates_total;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
