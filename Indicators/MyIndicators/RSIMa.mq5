//+------------------------------------------------------------------+
//|                                                        RSIMa.mq5 |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                                 https://mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://mql5.com"
#property version   "1.03" // Final robust version with manual calculation loop
#property description "Oscillator based on the Moving Average of RSI."

#property indicator_separate_window
#property indicator_level1 30.0
#property indicator_level2 50.0
#property indicator_level3 70.0

#property indicator_buffers 2
#property indicator_plots   2

//--- plot RSIMA (Smoothed RSI)
#property indicator_label1  "RSIMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- plot RSI (Raw RSI)
#property indicator_label2  "RSI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGreen
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- input parameters
input uint                 InpPeriodRSI      = 14;          // RSI period
input ENUM_APPLIED_PRICE   InpAppliedPrice   = PRICE_CLOSE; // RSI applied price
input uint                 InpPeriodMA       = 14;          // Smoothing period
input ENUM_MA_METHOD       InpMethod         = MODE_SMA;    // Smoothing method

//--- indicator buffers
double         BufferRSIMA[];    // Buffer for the smoothed RSI line (Plot 1)
double         BufferRawRSI[];   // Buffer for the raw RSI values (Plot 2)

//--- global variables
int            handle_rsi;

//--- includes
#include <MovingAverages.mqh>

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   int period_rsi = (int)InpPeriodRSI;
   if(period_rsi < 1)
      period_rsi = 1;

   int period_ma = (int)InpPeriodMA;
   if(period_ma < 1)
      period_ma = 1;

   SetIndexBuffer(0, BufferRSIMA,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferRawRSI, INDICATOR_DATA);

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RSIMA(%d, %d)", period_rsi, period_ma));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, period_rsi + period_ma - 1);
   PlotIndexSetString(0, PLOT_LABEL, "RSIMA");

   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, period_rsi - 1);
   PlotIndexSetString(1, PLOT_LABEL, "RSI");

   handle_rsi = iRSI(_Symbol, _Period, period_rsi, InpAppliedPrice);
   if(handle_rsi == INVALID_HANDLE)
     {
      PrintFormat("Failed to create iRSI handle. Error %d", GetLastError());
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   int period_rsi = (int)InpPeriodRSI;
   if(period_rsi < 1)
      period_rsi = 1;

   int period_ma = (int)InpPeriodMA;
   if(period_ma < 1)
      period_ma = 1;

   if(rates_total < period_rsi)
      return(0);

//--- Get all available RSI values into our buffer ---
   if(CopyBuffer(handle_rsi, 0, 0, rates_total, BufferRawRSI) != rates_total)
     {
      Print("Error copying RSI buffer.");
      return(0);
     }

//--- Manual calculation loop for robustness ---
   int start_pos;
// Determine the starting bar for calculation
   if(prev_calculated > 0)
     {
      // On subsequent calls, start from the last calculated bar
      start_pos = prev_calculated - 1;
     }
   else
     {
      // On the first call, start from the first bar where MA can be calculated
      start_pos = period_rsi + period_ma - 2;
     }

// The MA functions need non-timeseries arrays
   ArraySetAsSeries(BufferRawRSI, false);

// Loop through the bars that need calculation
   for(int i = start_pos; i < rates_total; i++)
     {
      // Check if we have enough data for the MA calculation at this position
      if(i < period_rsi + period_ma - 2)
        {
         BufferRSIMA[i] = EMPTY_VALUE;
         continue;
        }

      // Calculate the MA value for the current bar 'i'
      switch(InpMethod)
        {
         case MODE_EMA:
            // For EMA, we need the previous EMA value
            BufferRSIMA[i] = ExponentialMA(i, period_ma, BufferRSIMA[i-1], BufferRawRSI);
            break;
         case MODE_SMMA:
            // For SMMA, we also need the previous SMMA value
            BufferRSIMA[i] = SmoothedMA(i, period_ma, BufferRSIMA[i-1], BufferRawRSI);
            break;
         case MODE_LWMA:
            BufferRSIMA[i] = LinearWeightedMA(i, period_ma, BufferRawRSI);
            break;
         default: // MODE_SMA
            BufferRSIMA[i] = SimpleMA(i, period_ma, BufferRawRSI);
            break;
        }
     }

// Restore the timeseries property for the raw RSI buffer if needed elsewhere
   ArraySetAsSeries(BufferRawRSI, true);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
