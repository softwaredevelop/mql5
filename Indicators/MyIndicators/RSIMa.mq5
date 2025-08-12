//+------------------------------------------------------------------+
//|                                                        RSIMA.mq5 |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                                 https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.10" // Added robust data availability check
#property description "Oscillator based on the Moving Average of a standard RSI."

// --- Standard Includes ---
#include <MovingAverages.mqh>

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_level1 30.0
#property indicator_level2 50.0
#property indicator_level3 70.0

//--- Buffers and Plots ---
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: RSIMA (Smoothed RSI)
#property indicator_label1  "RSIMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: RSI (Raw RSI)
#property indicator_label2  "RSI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGreen
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Input Parameters ---
input uint                 InpPeriodRSI      = 14;          // Period for RSI
input ENUM_APPLIED_PRICE   InpAppliedPrice   = PRICE_CLOSE; // Applied price for RSI
input uint                 InpPeriodMA       = 14;          // Period for Moving Average
input ENUM_MA_METHOD       InpMethod         = MODE_SMA;    // Method for Moving Average

//--- Indicator Buffers ---
double    BufferRSIMA[];    // Buffer for the smoothed RSI line (Plot 1)
double    BufferRawRSI[];   // Buffer for the raw RSI values (Plot 2)

//--- Global Variables ---
int       ExtPeriodRSI;
int       ExtPeriodMA;
int       handle_rsi;       // Handle for the standard RSI indicator

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//| Called once when the indicator is first loaded.                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate and store input periods
   ExtPeriodRSI = (int)(InpPeriodRSI < 1 ? 1 : InpPeriodRSI);
   ExtPeriodMA  = (int)(InpPeriodMA < 1 ? 1 : InpPeriodMA);

//--- Map the buffers to the indicator's internal memory
   SetIndexBuffer(0, BufferRSIMA,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferRawRSI, INDICATOR_DATA);

//--- Set indicator display properties
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RSIMA(%d, %d)", ExtPeriodRSI, ExtPeriodMA));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtPeriodRSI + ExtPeriodMA - 1);
   PlotIndexSetString(0, PLOT_LABEL, "RSIMA");
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtPeriodRSI - 1);
   PlotIndexSetString(1, PLOT_LABEL, "RSI");

//--- Create a handle to the standard iRSI indicator
   handle_rsi = iRSI(_Symbol, _Period, ExtPeriodRSI, InpAppliedPrice);
   if(handle_rsi == INVALID_HANDLE)
     {
      PrintFormat("Failed to create iRSI handle. Error %d", GetLastError());
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation function.                           |
//| Called on every new tick or new bar.                             |
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
//--- Check if there is enough data for the initial calculation
   if(rates_total < ExtPeriodRSI)
      return(0);

//--- FIX: Check if the source indicator (iRSI) has calculated its data ---
// This prevents "Error copying buffer" when changing timeframes or on first load.
   int calculated_rsi = BarsCalculated(handle_rsi);
   if(calculated_rsi < rates_total)
     {
      // Not all data is ready yet, wait for the next OnCalculate call
      return(0);
     }

//--- Get all available RSI values into our buffer ---
   if(CopyBuffer(handle_rsi, 0, 0, rates_total, BufferRawRSI) <= 0)
     {
      // This might still happen occasionally, but the check above reduces it.
      Print("Error copying RSI buffer. LastError: ", GetLastError());
      return(0);
     }

//--- Calculate the Moving Average on the RSI buffer ---
// The MA functions need non-timeseries arrays
   ArraySetAsSeries(BufferRawRSI, false);
   ArraySetAsSeries(BufferRSIMA, false); // Also set the target buffer

   int start_pos;
   if(prev_calculated > 1)
      start_pos = prev_calculated - 1;
   else
      start_pos = ExtPeriodRSI + ExtPeriodMA - 2; // Start from the first valid bar

// Loop through the bars that need calculation
   for(int i = start_pos; i < rates_total; i++)
     {
      if(i < ExtPeriodRSI + ExtPeriodMA - 2)
         continue; // Skip bars with insufficient data for MA

      switch(InpMethod)
        {
         case MODE_EMA:
            BufferRSIMA[i] = ExponentialMA(i, ExtPeriodMA, BufferRSIMA[i-1], BufferRawRSI);
            break;
         case MODE_SMMA:
            BufferRSIMA[i] = SmoothedMA(i, ExtPeriodMA, BufferRSIMA[i-1], BufferRawRSI);
            break;
         case MODE_LWMA:
            BufferRSIMA[i] = LinearWeightedMA(i, ExtPeriodMA, BufferRawRSI);
            break;
         default: // MODE_SMA
            BufferRSIMA[i] = SimpleMA(i, ExtPeriodMA, BufferRawRSI);
            break;
        }
     }

// It's good practice to restore the series state if other parts of the code might expect it
   ArraySetAsSeries(BufferRawRSI, true);
   ArraySetAsSeries(BufferRSIMA, true);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
