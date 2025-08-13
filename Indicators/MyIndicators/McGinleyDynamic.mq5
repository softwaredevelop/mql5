//+------------------------------------------------------------------+
//|                                           McGinleyDynamic.mq5    |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "McGinley Dynamic Indicator"

#include <MovingAverages.mqh>

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
input int                InpLength = 14;      // Period
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // Applied Price

//--- Indicator Buffers ---
double    BufferMcGinley[];
double    BufferPrice[];

//--- Global Variables ---
int       ExtLength;
int       price_handle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- Validate and store input
   ExtLength = (InpLength < 1) ? 1 : InpLength;

//--- Map the buffers and set as non-timeseries
   SetIndexBuffer(0, BufferMcGinley, INDICATOR_DATA);
   SetIndexBuffer(1, BufferPrice,    INDICATOR_CALCULATIONS);
   ArraySetAsSeries(BufferMcGinley, false);
   ArraySetAsSeries(BufferPrice,    false);

//--- Create a handle to get the source price data
   price_handle = iMA(_Symbol, _Period, 1, 0, MODE_SMA, InpAppliedPrice);
   if(price_handle == INVALID_HANDLE)
     {
      Print("Error creating price source handle (iMA).");
     }

//--- Set indicator display properties
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtLength);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("McGinley(%d)", ExtLength));
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
//--- Check for enough data
   if(rates_total < ExtLength)
      return(0);

//--- Check if the source indicator is ready
   if(BarsCalculated(price_handle) < rates_total)
      return(0);

//--- Copy the source price data into our buffer
   if(CopyBuffer(price_handle, 0, 0, rates_total, BufferPrice) != rates_total)
      return(0);

//--- Main calculation loop (full recalculation for stability)
   for(int i = 1; i < rates_total; i++) // Start from 1 to access i-1
     {
      // Skip until we have enough data
      if(i < ExtLength)
        {
         BufferMcGinley[i] = EMPTY_VALUE;
         continue;
        }

      // --- Initialization Step ---
      // The first McGinley value is an EMA of the source price
      if(i == ExtLength)
        {
         // To calculate the first EMA, we need an SMA as a starting point
         BufferMcGinley[i] = SimpleMA(i, ExtLength, BufferPrice);
         continue; // Move to the next bar
        }

      // --- Recursive Calculation Step ---
      double prev_mg = BufferMcGinley[i-1];
      double source = BufferPrice[i];

      // Avoid division by zero if previous value is 0
      if(prev_mg == 0)
        {
         BufferMcGinley[i] = source; // Fallback to the current price
         continue;
        }

      // The core McGinley Dynamic formula
      double ratio = source / prev_mg;
      double denominator = ExtLength * MathPow(ratio, 4);

      // Another check to avoid division by zero
      if(denominator == 0)
        {
         BufferMcGinley[i] = prev_mg; // Keep the previous value
         continue;
        }

      BufferMcGinley[i] = prev_mg + (source - prev_mg) / denominator;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
