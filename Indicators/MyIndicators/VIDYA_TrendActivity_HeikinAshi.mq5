//+------------------------------------------------------------------+
//|                                    VIDYA_TrendActivity_HeikinAshi.mq5|
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Adjusted vertical scale
#property description "Measures the trend activity of a Heikin Ashi VIDYA line using Arctan normalization."
#property description "High values suggest a trending market, low values suggest a flat/ranging market."

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2
#property indicator_label1  "HA_Activity"
#property indicator_minimum 0.0
#property indicator_maximum 0.5 // Adjusted for better visualization

//--- Enum for selecting Heikin Ashi price source ---
enum ENUM_HA_APPLIED_PRICE
  {
   HA_PRICE_CLOSE, // Heikin Ashi Close
   HA_PRICE_OPEN,  // Heikin Ashi Open
   HA_PRICE_HIGH,  // Heikin Ashi High
   HA_PRICE_LOW,   // Heikin Ashi Low
  };

//--- Input Parameters ---
input group              "VIDYA Settings"
input int                InpPeriodCMO    = 9;
input int                InpPeriodEMA    = 12;
input ENUM_HA_APPLIED_PRICE InpAppliedPrice = HA_PRICE_CLOSE;
input group              "Activity Calculation Settings"
input int                InpAtrPeriod    = 14;
input int                InpSmoothingPeriod = 5;

//--- Indicator Buffers ---
double    BufferActivity[];

//--- Global Objects and Variables ---
int                       g_ExtPeriodCMO, g_ExtPeriodEMA, g_ExtAtrPeriod, g_ExtSmoothingPeriod;
double                    g_M_PI_2;
CHeikinAshi_Calculator   *g_ha_calculator;

//--- Forward declarations ---
double CalculateCMO(int position, int period, const double &price_array[]);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtPeriodCMO       = (InpPeriodCMO < 1) ? 1 : InpPeriodCMO;
   g_ExtPeriodEMA       = (InpPeriodEMA < 1) ? 1 : InpPeriodEMA;
   g_ExtAtrPeriod       = (InpAtrPeriod < 1) ? 1 : InpAtrPeriod;
   g_ExtSmoothingPeriod = (InpSmoothingPeriod < 1) ? 1 : InpSmoothingPeriod;
   g_M_PI_2             = M_PI / 2.0;

   SetIndexBuffer(0, BufferActivity, INDICATOR_DATA);
   ArraySetAsSeries(BufferActivity, false);

   int draw_begin = g_ExtPeriodCMO + g_ExtPeriodEMA + g_ExtAtrPeriod + g_ExtSmoothingPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA VIDYA Activity(%d,%d,%d,%d)", g_ExtPeriodCMO, g_ExtPeriodEMA, g_ExtAtrPeriod, g_ExtSmoothingPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 4);

//--- Programmatically set the vertical scale for better visualization
   IndicatorSetDouble(INDICATOR_MINIMUM, 0.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 0.5);

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
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
     {
      delete g_ha_calculator;
      g_ha_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| VIDYA Trend Activity on Heikin Ashi calculation function.        |
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
   int start_pos = g_ExtPeriodCMO + g_ExtPeriodEMA + g_ExtAtrPeriod + g_ExtSmoothingPeriod;
   if(rates_total <= start_pos)
      return(0);

//--- Intermediate Heikin Ashi Buffers
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- STEP 2: Prepare the Heikin Ashi source price array for VIDYA
   double ha_price_source[];
   ArrayResize(ha_price_source, rates_total);
   switch(InpAppliedPrice)
     {
      case HA_PRICE_OPEN:
         ArrayCopy(ha_price_source, ha_open);
         break;
      case HA_PRICE_HIGH:
         ArrayCopy(ha_price_source, ha_high);
         break;
      case HA_PRICE_LOW:
         ArrayCopy(ha_price_source, ha_low);
         break;
      default:
         ArrayCopy(ha_price_source, ha_close);
         break;
     }

//--- STEP 3: Calculate Heikin Ashi VIDYA
   double buffer_vidya[];
   ArrayResize(buffer_vidya, rates_total);
   double alpha = 2.0 / (g_ExtPeriodEMA + 1.0);
   int vidya_start_pos = g_ExtPeriodCMO + g_ExtPeriodEMA;

   for(int i = 1; i < rates_total; i++)
     {
      if(i == vidya_start_pos)
        {
         double sum = 0;
         for(int j=0; j<g_ExtPeriodEMA; j++)
            sum += ha_price_source[i-j];
         buffer_vidya[i] = sum / g_ExtPeriodEMA;
         continue;
        }
      if(i > vidya_start_pos)
        {
         double cmo = MathAbs(CalculateCMO(i, g_ExtPeriodCMO, ha_price_source));
         buffer_vidya[i] = ha_price_source[i] * alpha * cmo + buffer_vidya[i-1] * (1 - alpha * cmo);
        }
     }

//--- STEP 4: Calculate Heikin Ashi ATR
   double buffer_atr[];
   ArrayResize(buffer_atr, rates_total);
   double ha_tr[];
   ArrayResize(ha_tr, rates_total);
   for(int i = 1; i < rates_total; i++)
     {
      ha_tr[i] = MathMax(ha_high[i], ha_close[i-1]) - MathMin(ha_low[i], ha_close[i-1]);
     }
   for(int i = 1; i < rates_total; i++)
     {
      if(i == g_ExtAtrPeriod)
        {
         double sum_tr = 0;
         for(int j = 1; j <= g_ExtAtrPeriod; j++)
            sum_tr += ha_tr[j];
         buffer_atr[i] = sum_tr / g_ExtAtrPeriod;
        }
      else
         if(i > g_ExtAtrPeriod)
           {
            buffer_atr[i] = (buffer_atr[i-1] * (g_ExtAtrPeriod - 1) + ha_tr[i]) / g_ExtAtrPeriod;
           }
     }

//--- STEP 5: Calculate Raw Activity and Scale it using MathArctan
   double scaled_activity[];
   ArrayResize(scaled_activity, rates_total);
   for(int i = vidya_start_pos + 1; i < rates_total; i++)
     {
      if(buffer_atr[i] > 0)
        {
         double raw_activity = MathAbs(buffer_vidya[i] - buffer_vidya[i-1]) / buffer_atr[i];
         scaled_activity[i] = MathArctan(raw_activity) / g_M_PI_2;
        }
     }

//--- STEP 6: Calculate Final Oscillator (SMA of Scaled Activity)
   double sum = 0;
   int final_start_pos = vidya_start_pos + g_ExtSmoothingPeriod;
   for(int i = vidya_start_pos + 1; i < rates_total; i++)
     {
      sum += scaled_activity[i];
      if(i >= final_start_pos)
        {
         if(i > final_start_pos)
           {
            sum -= scaled_activity[i - g_ExtSmoothingPeriod];
           }
         BufferActivity[i] = sum / g_ExtSmoothingPeriod;
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Calculates Chande Momentum Oscillator (CMO) for a given position |
//+------------------------------------------------------------------+
double CalculateCMO(int position, int period, const double &price_array[])
  {
   if(position < period)
      return 0.0;

   double sum_up = 0.0;
   double sum_down = 0.0;

   for(int i = 0; i < period; i++)
     {
      double diff = price_array[position - i] - price_array[position - i - 1];
      if(diff > 0.0)
         sum_up += diff;
      else
         sum_down += (-diff);
     }

   if(sum_up + sum_down == 0.0)
      return 0.0;

   return (sum_up - sum_down) / (sum_up + sum_down);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
