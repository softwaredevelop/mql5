//+------------------------------------------------------------------+
//|                                          ALMA_HeikinAshi.mq5     |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.01" // Fixed indexing logic in ALMA calculation
#property description "Arnaud Legoux Moving Average (ALMA) on Heikin Ashi data"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: ALMA line
#property indicator_label1  "HA_ALMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumVioletRed
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
input int                  InpAlmaPeriod   = 9;
input ENUM_HA_APPLIED_PRICE InpAppliedPrice = HA_PRICE_CLOSE;
input double               InpAlmaOffset   = 0.85;
input double               InpAlmaSigma    = 6.0;

//--- Indicator Buffers ---
double    BufferHA_ALMA[];

//--- Intermediate Heikin Ashi Buffers ---
double    ExtHaOpenBuffer[];
double    ExtHaHighBuffer[];
double    ExtHaLowBuffer[];
double    ExtHaCloseBuffer[];

//--- Global Objects and Variables ---
int                       g_ExtAlmaPeriod;
double                    g_ExtAlmaOffset;
double                    g_ExtAlmaSigma;
CHeikinAshi_Calculator   *g_ha_calculator; // Pointer to our Heikin Ashi calculator

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtAlmaPeriod = (InpAlmaPeriod < 1) ? 1 : InpAlmaPeriod;
   g_ExtAlmaOffset = InpAlmaOffset;
   g_ExtAlmaSigma  = (InpAlmaSigma <= 0) ? 0.01 : InpAlmaSigma;

   SetIndexBuffer(0, BufferHA_ALMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferHA_ALMA, false);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtAlmaPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_ALMA(%d, %.2f, %.1f)", g_ExtAlmaPeriod, g_ExtAlmaOffset, g_ExtAlmaSigma));

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
//| Arnaud Legoux Moving Average calculation function.               |
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
   if(rates_total < g_ExtAlmaPeriod)
      return(0);

//--- Resize intermediate buffers to match the available bars
   ArrayResize(ExtHaOpenBuffer, rates_total);
   ArrayResize(ExtHaHighBuffer, rates_total);
   ArrayResize(ExtHaLowBuffer, rates_total);
   ArrayResize(ExtHaCloseBuffer, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars using our toolkit
   g_ha_calculator.Calculate(rates_total, open, high, low, close,
                             ExtHaOpenBuffer, ExtHaHighBuffer, ExtHaLowBuffer, ExtHaCloseBuffer);

//--- STEP 2: Select the source price array for ALMA calculation
   double source_array[];
   switch(InpAppliedPrice)
     {
      case HA_PRICE_OPEN:
         ArrayCopy(source_array, ExtHaOpenBuffer);
         break;
      case HA_PRICE_HIGH:
         ArrayCopy(source_array, ExtHaHighBuffer);
         break;
      case HA_PRICE_LOW:
         ArrayCopy(source_array, ExtHaLowBuffer);
         break;
      default: // HA_PRICE_CLOSE
         ArrayCopy(source_array, ExtHaCloseBuffer);
         break;
     }

//--- STEP 3: Calculate ALMA based on the selected HA price array
   double m = g_ExtAlmaOffset * (g_ExtAlmaPeriod - 1.0);
   double s = (double)g_ExtAlmaPeriod / g_ExtAlmaSigma;

// The main loop iterates through all bars that can be calculated
   for(int i = g_ExtAlmaPeriod - 1; i < rates_total; i++)
     {
      double sum = 0.0;
      double norm = 0.0;

      // The inner loop calculates the weighted sum for the current bar 'i'
      for(int j = 0; j < g_ExtAlmaPeriod; j++)
        {
         double weight = MathExp(-1 * MathPow(j - m, 2) / (2 * s * s));

         // *** FIX: Reverted to the original, correct indexing logic ***
         // This ensures the weight for position 'j' is applied to the correct price in the window.
         int price_index = i - (g_ExtAlmaPeriod - 1) + j;

         sum += source_array[price_index] * weight;
         norm += weight;
        }

      if(norm > 0)
         BufferHA_ALMA[i] = sum / norm;
      else
         BufferHA_ALMA[i] = 0.0;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
