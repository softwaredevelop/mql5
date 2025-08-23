//+------------------------------------------------------------------+
//|                                 McGinleyDynamic_HeikinAshi.mq5   |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored for full recalculation and stability
#property description "McGinley Dynamic Indicator on Heikin Ashi data"

#include <MyIncludes\HeikinAshi_Tools.mqh>

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

//--- Enum for selecting Heikin Ashi price source ---
enum ENUM_HA_APPLIED_PRICE
  {
   HA_PRICE_CLOSE, // Heikin Ashi Close
   HA_PRICE_OPEN,  // Heikin Ashi Open
   HA_PRICE_HIGH,  // Heikin Ashi High
   HA_PRICE_LOW,   // Heikin Ashi Low
  };

//--- Input Parameters ---
input int                  InpLength       = 14;
input ENUM_HA_APPLIED_PRICE InpAppliedPrice = HA_PRICE_CLOSE;

//--- Indicator Buffers ---
double    BufferHA_McGinley[];

//--- Intermediate Heikin Ashi Buffers ---
double    ExtHaOpenBuffer[];
double    ExtHaHighBuffer[];
double    ExtHaLowBuffer[];
double    ExtHaCloseBuffer[];

//--- Global Objects and Variables ---
int                       g_ExtLength;
CHeikinAshi_Calculator   *g_ha_calculator; // Pointer to our Heikin Ashi calculator

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtLength = (InpLength < 1) ? 1 : InpLength;

   SetIndexBuffer(0, BufferHA_McGinley, INDICATOR_DATA);
   ArraySetAsSeries(BufferHA_McGinley, false);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1); // McGinley can be drawn from the 2nd bar
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_McGinley(%d)", g_ExtLength));

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
//--- Free the calculator object
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
     {
      delete g_ha_calculator;
      g_ha_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| McGinley Dynamic on Heikin Ashi calculation function.            |
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
   if(rates_total < 2)
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

//--- STEP 3: Main calculation loop for McGinley Dynamic
   for(int i = 0; i < rates_total; i++)
     {
      // --- Initialization Step ---
      if(i == 0)
        {
         // The first McGinley value is simply the first source price
         BufferHA_McGinley[i] = ha_price_source[i];
         continue;
        }

      // --- Recursive Calculation Step ---
      double prev_mg = BufferHA_McGinley[i-1];

      // Prevent division by zero if the previous value was somehow zero
      if(prev_mg == 0)
        {
         BufferHA_McGinley[i] = ha_price_source[i];
         continue;
        }

      double denominator = g_ExtLength * MathPow(ha_price_source[i] / prev_mg, 4);

      // Prevent division by zero if the denominator becomes zero
      if(denominator == 0)
        {
         BufferHA_McGinley[i] = prev_mg;
         continue;
        }

      BufferHA_McGinley[i] = prev_mg + (ha_price_source[i] - prev_mg) / denominator;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
