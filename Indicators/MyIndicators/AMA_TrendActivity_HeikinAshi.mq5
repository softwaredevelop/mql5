//+------------------------------------------------------------------+
//|                                AMA_TrendActivity_HeikinAshi.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Measures the trend activity of a Heikin Ashi AMA line using Arctan normalization."
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
#property indicator_maximum 0.5

//--- Enum for selecting Heikin Ashi price source ---
enum ENUM_HA_APPLIED_PRICE
  {
   HA_PRICE_CLOSE, HA_PRICE_OPEN, HA_PRICE_HIGH, HA_PRICE_LOW
  };

//--- Input Parameters ---
input group                 "AMA Settings"
input int                   InpAmaPeriod    = 10;
input int                   InpFastEmaPeriod= 2;
input int                   InpSlowEmaPeriod= 30;
input ENUM_HA_APPLIED_PRICE InpAppliedPrice = HA_PRICE_CLOSE;
input group                 "Activity Calculation Settings"
input int                   InpAtrPeriod    = 14;
input int                   InpSmoothingPeriod = 5;

//--- Indicator Buffers ---
double    BufferActivity[];

//--- Global Objects and Variables ---
int                       g_ExtAmaPeriod, g_ExtFastEmaPeriod, g_ExtSlowEmaPeriod, g_ExtAtrPeriod, g_ExtSmoothingPeriod;
double                    g_M_PI_2;
CHeikinAshi_Calculator   *g_ha_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtAmaPeriod       = (InpAmaPeriod < 1) ? 1 : InpAmaPeriod;
   g_ExtFastEmaPeriod   = (InpFastEmaPeriod < 1) ? 1 : InpFastEmaPeriod;
   g_ExtSlowEmaPeriod   = (InpSlowEmaPeriod < 1) ? 1 : InpSlowEmaPeriod;
   g_ExtAtrPeriod       = (InpAtrPeriod < 1) ? 1 : InpAtrPeriod;
   g_ExtSmoothingPeriod = (InpSmoothingPeriod < 1) ? 1 : InpSmoothingPeriod;
   g_M_PI_2             = M_PI / 2.0;

   SetIndexBuffer(0, BufferActivity, INDICATOR_DATA);
   ArraySetAsSeries(BufferActivity, false);

   int draw_begin = g_ExtAmaPeriod + g_ExtAtrPeriod + g_ExtSmoothingPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA AMA Activity(%d,%d,%d)", g_ExtAmaPeriod, g_ExtAtrPeriod, g_ExtSmoothingPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 4);

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
//| AMA Trend Activity on Heikin Ashi calculation function.          |
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
   int start_pos = g_ExtAmaPeriod + g_ExtAtrPeriod + g_ExtSmoothingPeriod;
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

//--- STEP 2: Prepare the Heikin Ashi source price array for AMA
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

//--- STEP 3: Calculate AMA on HA data
   double buffer_ama[];
   ArrayResize(buffer_ama, rates_total);
   double fast_sc = 2.0 / (g_ExtFastEmaPeriod + 1.0);
   double slow_sc = 2.0 / (g_ExtSlowEmaPeriod + 1.0);

   for(int i = 1; i < rates_total; i++)
     {
      if(i == g_ExtAmaPeriod)
        {
         buffer_ama[i] = ha_price_source[i];
         continue;
        }
      if(i > g_ExtAmaPeriod)
        {
         double direction = MathAbs(ha_price_source[i] - ha_price_source[i - g_ExtAmaPeriod]);
         double volatility = 0;
         for(int j = 0; j < g_ExtAmaPeriod; j++)
           {
            volatility += MathAbs(ha_price_source[i - j] - ha_price_source[i - j - 1]);
           }
         double er = (volatility > 0) ? direction / volatility : 0;
         double ssc = er * (fast_sc - slow_sc) + slow_sc;
         double ssc_sq = ssc * ssc;
         buffer_ama[i] = buffer_ama[i-1] + ssc_sq * (ha_price_source[i] - buffer_ama[i-1]);
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
   for(int i = g_ExtAmaPeriod + 1; i < rates_total; i++)
     {
      if(buffer_atr[i] > 0)
        {
         double raw_activity = MathAbs(buffer_ama[i] - buffer_ama[i-1]) / buffer_atr[i];
         scaled_activity[i] = MathArctan(raw_activity) / g_M_PI_2;
        }
     }

//--- STEP 6: Calculate Final Oscillator (SMA of Scaled Activity)
   double sum = 0;
   int final_start_pos = g_ExtAmaPeriod + g_ExtSmoothingPeriod;
   for(int i = g_ExtAmaPeriod + 1; i < rates_total; i++)
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
//+------------------------------------------------------------------+
