//+------------------------------------------------------------------+
//|                                                          HMA.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored to use direct calculation, no handles
#property description "Hull Moving Average (HMA)"

#include <MovingAverages.mqh>

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
input int                InpPeriodHMA    = 14;
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE;

//--- Indicator Buffers ---
double    BufferHMA[];
double    BufferWMA_Half[];
double    BufferWMA_Full[];
double    BufferRawHMA[];
double    BufferPrice[]; // Buffer for the source price data

//--- Global Variables ---
int       ExtPeriodHMA;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
void OnInit()
  {
   ExtPeriodHMA = (InpPeriodHMA < 1) ? 1 : InpPeriodHMA;

   SetIndexBuffer(0, BufferHMA,      INDICATOR_DATA);
   SetIndexBuffer(1, BufferWMA_Half, INDICATOR_CALCULATIONS);
   SetIndexBuffer(2, BufferWMA_Full, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferRawHMA,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferPrice,    INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferHMA,      false);
   ArraySetAsSeries(BufferWMA_Half, false);
   ArraySetAsSeries(BufferWMA_Full, false);
   ArraySetAsSeries(BufferRawHMA,   false);
   ArraySetAsSeries(BufferPrice,    false);

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
   if(rates_total < ExtPeriodHMA)
      return(0);

//--- STEP 1: Get the source price data ---
// This replaces the iMA handle logic
   switch(InpAppliedPrice)
     {
      case PRICE_OPEN:
         ArrayCopy(BufferPrice, open);
         break;
      case PRICE_HIGH:
         ArrayCopy(BufferPrice, high);
         break;
      case PRICE_LOW:
         ArrayCopy(BufferPrice, low);
         break;
      default:
         ArrayCopy(BufferPrice, close);
         break;
     }

//--- STEP 2: Calculate the two base WMAs
   int period_half = (int)MathMax(1, MathRound(ExtPeriodHMA / 2.0));
   for(int i = 0; i < rates_total; i++)
     {
      if(i >= period_half - 1)
         BufferWMA_Half[i] = LinearWeightedMA(i, period_half, BufferPrice);
      if(i >= ExtPeriodHMA - 1)
         BufferWMA_Full[i] = LinearWeightedMA(i, ExtPeriodHMA, BufferPrice);
     }

//--- STEP 3: Calculate the raw HMA data
   for(int i = ExtPeriodHMA - 1; i < rates_total; i++)
     {
      BufferRawHMA[i] = 2 * BufferWMA_Half[i] - BufferWMA_Full[i];
     }

//--- STEP 4: Smooth the raw HMA with the final WMA
   int period_sqrt = (int)MathMax(1, MathRound(MathSqrt(ExtPeriodHMA)));
   for(int i = ExtPeriodHMA + period_sqrt - 2; i < rates_total; i++)
     {
      BufferHMA[i] = LinearWeightedMA(i, period_sqrt, BufferRawHMA);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
