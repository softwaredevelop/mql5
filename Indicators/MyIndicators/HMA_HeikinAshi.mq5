//+------------------------------------------------------------------+
//|                                          HMA_HeikinAshi.mq5      |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored for full recalculation and stability
#property description "Hull Moving Average (HMA) on Heikin Ashi data"

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MovingAverages.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   1

//--- Plot 1: HMA line
#property indicator_label1  "HA_HMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepPink
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Enum for selecting Heikin Ashi price source ---
enum ENUM_HA_APPLIED_PRICE
  {
   HA_PRICE_CLOSE, // Heikin Ashi Close
   HA_PRICE_OPEN,  // Heikin Ashi Open
   HA_PRICE_HIGH,  // Heikin Ashi High
   HA_PRICE_LOW,   // Heikin Ashi Low
  };

//--- Input Parameters ---
input int                  InpPeriodHMA    = 14;
input ENUM_HA_APPLIED_PRICE InpAppliedPrice = HA_PRICE_CLOSE;

//--- Indicator Buffers ---
double    BufferHA_HMA[];
double    BufferWMA_Half[];
double    BufferWMA_Full[];
double    BufferRawHMA[];

//--- Intermediate Heikin Ashi Buffers ---
double    ExtHaOpenBuffer[];
double    ExtHaHighBuffer[];
double    ExtHaLowBuffer[];
double    ExtHaCloseBuffer[];

//--- Global Objects and Variables ---
int                       g_ExtPeriodHMA;
CHeikinAshi_Calculator   *g_ha_calculator; // Pointer to our Heikin Ashi calculator

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtPeriodHMA = (InpPeriodHMA < 1) ? 1 : InpPeriodHMA;

   SetIndexBuffer(0, BufferHA_HMA,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferWMA_Half, INDICATOR_CALCULATIONS);
   SetIndexBuffer(2, BufferWMA_Full, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferRawHMA,   INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferHA_HMA,   false);
   ArraySetAsSeries(BufferWMA_Half, false);
   ArraySetAsSeries(BufferWMA_Full, false);
   ArraySetAsSeries(BufferRawHMA,   false);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtPeriodHMA + (int)MathFloor(MathSqrt(g_ExtPeriodHMA)) - 2);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_HMA(%d)", g_ExtPeriodHMA));

//--- Create the calculator instance
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
//--- Free the calculator object to prevent memory leaks
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
     {
      delete g_ha_calculator;
      g_ha_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Hull Moving Average on Heikin Ashi calculation function.         |
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
   int start_pos = g_ExtPeriodHMA + (int)MathFloor(MathSqrt(g_ExtPeriodHMA)) - 2;
   if(rates_total <= start_pos)
      return(0);

//--- Resize intermediate buffers
   ArrayResize(ExtHaOpenBuffer, rates_total);
   ArrayResize(ExtHaHighBuffer, rates_total);
   ArrayResize(ExtHaLowBuffer, rates_total);
   ArrayResize(ExtHaCloseBuffer, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close,
                             ExtHaOpenBuffer, ExtHaHighBuffer, ExtHaLowBuffer, ExtHaCloseBuffer);

//--- STEP 2: Select the source Heikin Ashi price array
   double ha_price_source[];
   switch(InpAppliedPrice)
     {
      case HA_PRICE_OPEN:
         ArrayCopy(ha_price_source, ExtHaOpenBuffer);
         break;
      case HA_PRICE_HIGH:
         ArrayCopy(ha_price_source, ExtHaHighBuffer);
         break;
      case HA_PRICE_LOW:
         ArrayCopy(ha_price_source, ExtHaLowBuffer);
         break;
      default:
         ArrayCopy(ha_price_source, ExtHaCloseBuffer);
         break;
     }

//--- STEP 3: Calculate all HMA components in a single, efficient loop
   int period_half = (int)MathMax(1, MathRound(g_ExtPeriodHMA / 2.0));
   int period_sqrt = (int)MathMax(1, MathRound(MathSqrt(g_ExtPeriodHMA)));

   for(int i = g_ExtPeriodHMA - 1; i < rates_total; i++)
     {
      // Calculate the two base WMAs
      BufferWMA_Half[i] = LinearWeightedMA(i, period_half, ha_price_source);
      BufferWMA_Full[i] = LinearWeightedMA(i, g_ExtPeriodHMA, ha_price_source);

      // Calculate the raw HMA
      BufferRawHMA[i] = 2 * BufferWMA_Half[i] - BufferWMA_Full[i];
     }

//--- STEP 4: Smooth the raw HMA with the final WMA
   for(int i = start_pos; i < rates_total; i++)
     {
      BufferHA_HMA[i] = LinearWeightedMA(i, period_sqrt, BufferRawHMA);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
