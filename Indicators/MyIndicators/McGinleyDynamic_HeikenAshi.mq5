//+------------------------------------------------------------------+
//|                                  McGinleyDynamic_HeikenAshi.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.01" // Corrected array handling
#property description "McGinley Dynamic Indicator on Heiken Ashi data"

#include <MovingAverages.mqh>
#include <MyIncludes\HA_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: McGinley Dynamic line
#property indicator_label1  "HA_McGinley"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Enum for selecting Heiken Ashi price source ---
enum ENUM_HA_APPLIED_PRICE
  {
   HA_PRICE_CLOSE, // Heiken Ashi Close
   HA_PRICE_OPEN,  // Heiken Ashi Open
   HA_PRICE_HIGH,  // Heiken Ashi High
   HA_PRICE_LOW,   // Heiken Ashi Low
  };

//--- Input Parameters ---
input int                  InpLength       = 14;
input ENUM_HA_APPLIED_PRICE InpAppliedPrice = HA_PRICE_CLOSE;

//--- Indicator Buffers ---
double    BufferHA_McGinley[];

//--- Global Objects and Variables ---
int              ExtLength;
CHA_Calculator   g_ha_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
void OnInit()
  {
   ExtLength = (InpLength < 1) ? 1 : InpLength;

   SetIndexBuffer(0, BufferHA_McGinley, INDICATOR_DATA);
   ArraySetAsSeries(BufferHA_McGinley, false);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtLength);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_McGinley(%d)", ExtLength));
  }

//+------------------------------------------------------------------+
//| McGinley Dynamic on Heiken Ashi calculation function.            |
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
   if(rates_total < ExtLength)
      return(0);

//--- STEP 1: Calculate Heiken Ashi bars using our toolkit
   if(!g_ha_calculator.Calculate(rates_total, 0, open, high, low, close))
      return(0);

//--- STEP 2: Main calculation loop
   for(int i = 1; i < rates_total; i++)
     {
      if(i < ExtLength)
        {
         BufferHA_McGinley[i] = EMPTY_VALUE;
         continue;
        }

      // Select the source price for the current bar 'i'
      double source_price = 0;
      switch(InpAppliedPrice)
        {
         case HA_PRICE_OPEN:
            source_price = g_ha_calculator.ha_open[i];
            break;
         case HA_PRICE_HIGH:
            source_price = g_ha_calculator.ha_high[i];
            break;
         case HA_PRICE_LOW:
            source_price = g_ha_calculator.ha_low[i];
            break;
         default:
            source_price = g_ha_calculator.ha_close[i];
            break;
        }

      // --- Initialization Step ---
      if(i == ExtLength)
        {
         // The first McGinley value is an SMA of the source HA price
         // We need to create a temporary array for the SMA function
         double temp_price_array[];
         switch(InpAppliedPrice)
           {
            case HA_PRICE_OPEN:
               ArrayCopy(temp_price_array, g_ha_calculator.ha_open);
               break;
            case HA_PRICE_HIGH:
               ArrayCopy(temp_price_array, g_ha_calculator.ha_high);
               break;
            case HA_PRICE_LOW:
               ArrayCopy(temp_price_array, g_ha_calculator.ha_low);
               break;
            default:
               ArrayCopy(temp_price_array, g_ha_calculator.ha_close);
               break;
           }
         BufferHA_McGinley[i] = SimpleMA(i, ExtLength, temp_price_array);
         continue;
        }

      // --- Recursive Calculation Step ---
      double prev_mg = BufferHA_McGinley[i-1];

      if(prev_mg == 0)
        {
         BufferHA_McGinley[i] = source_price;
         continue;
        }

      double ratio = source_price / prev_mg;
      double denominator = ExtLength * MathPow(ratio, 4);

      if(denominator == 0)
        {
         BufferHA_McGinley[i] = prev_mg;
         continue;
        }

      BufferHA_McGinley[i] = prev_mg + (source_price - prev_mg) / denominator;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
