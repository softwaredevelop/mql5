//+------------------------------------------------------------------+
//|                                                          HMA.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Hull Moving Average (HMA)"

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 4 // HMA, and 3 calculation buffers
#property indicator_plots   1

//--- Plot 1: HMA line
#property indicator_label1  "HMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepPink
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int                InpPeriodHMA    = 14;      // HMA Period
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // Applied Price

//--- Indicator Buffers ---
double    BufferHMA[];        // Final HMA line
double    BufferWMA_Half[];   // WMA(period/2)
double    BufferWMA_Full[];   // WMA(period)
double    BufferRawHMA[];     // Raw HMA (2*WMA_Half - WMA_Full)

//--- Global Variables ---
int       ExtPeriodHMA;
int       handle_wma_half;
int       handle_wma_full;

//--- Include for WMA calculation ---
#include <MovingAverages.mqh>

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- Validate and store input period
   ExtPeriodHMA = (InpPeriodHMA < 1) ? 1 : InpPeriodHMA;

//--- Map the buffers
   SetIndexBuffer(0, BufferHMA,      INDICATOR_DATA);
   SetIndexBuffer(1, BufferWMA_Half, INDICATOR_CALCULATIONS);
   SetIndexBuffer(2, BufferWMA_Full, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferRawHMA,   INDICATOR_CALCULATIONS);

//--- Create handles to the standard iWMA indicator
   int period_half = (int)MathMax(1, MathRound(ExtPeriodHMA / 2.0));
   handle_wma_half = iMA(_Symbol, _Period, period_half, 0, MODE_LWMA, InpAppliedPrice);
   handle_wma_full = iMA(_Symbol, _Period, ExtPeriodHMA, 0, MODE_LWMA, InpAppliedPrice);

   if(handle_wma_half == INVALID_HANDLE || handle_wma_full == INVALID_HANDLE)
     {
      Print("Error creating iWMA handles.");
      return;
     }

//--- Set indicator display properties
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtPeriodHMA + (int)MathFloor(MathSqrt(ExtPeriodHMA)) - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HMA(%d)", ExtPeriodHMA));
  }

//+------------------------------------------------------------------+
//| Hull Moving Average calculation function.                        |
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
//--- Check if there is enough data
   if(rates_total < ExtPeriodHMA)
      return(0);

//--- Check if the source WMA indicators have calculated their data
   if(BarsCalculated(handle_wma_half) < rates_total || BarsCalculated(handle_wma_full) < rates_total)
      return(0);

//--- STEP 1 & 2: Get the two WMA values
   if(CopyBuffer(handle_wma_half, 0, 0, rates_total, BufferWMA_Half) <= 0 ||
      CopyBuffer(handle_wma_full, 0, 0, rates_total, BufferWMA_Full) <= 0)
     {
      return(0);
     }

//--- STEP 3: Calculate the raw HMA data
   for(int i = 0; i < rates_total; i++)
     {
      BufferRawHMA[i] = 2 * BufferWMA_Half[i] - BufferWMA_Full[i];
     }

//--- STEP 4: Smooth the raw HMA with another WMA to get the final HMA
   int period_sqrt = (int)MathMax(1, MathRound(MathSqrt(ExtPeriodHMA)));

// We use our stable, manual calculation loop for the final smoothing
   ArraySetAsSeries(BufferRawHMA, false); // WMA function needs non-timeseries
   ArraySetAsSeries(BufferHMA, false);

   for(int i = ExtPeriodHMA - 1; i < rates_total; i++)
     {
      BufferHMA[i] = LinearWeightedMA(i, period_sqrt, BufferRawHMA);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
