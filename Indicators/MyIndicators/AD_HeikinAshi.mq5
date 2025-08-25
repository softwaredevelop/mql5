//+------------------------------------------------------------------+
//|                                           AD_HeikinAshi.mq5      |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Accumulation/Distribution Line on Heikin Ashi data"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_label1  "HA_A/D"

//--- Input Parameters ---
input ENUM_APPLIED_VOLUME InpVolumeType = VOLUME_TICK; // Volume type

//--- Indicator Buffers ---
double    BufferAD[];

//--- Global Objects and Variables ---
CHeikinAshi_Calculator   *g_ha_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferAD, INDICATOR_DATA);
   ArraySetAsSeries(BufferAD, false);

   IndicatorSetInteger(INDICATOR_DIGITS, 0);
   IndicatorSetString(INDICATOR_SHORTNAME, "HA_A/D");
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);

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
//| A/D on Heikin Ashi calculation function.                         |
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

//--- Intermediate Heikin Ashi Buffers
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- STEP 2: Main calculation loop on HA data
   for(int i = 0; i < rates_total; i++)
     {
      double mfm = 0; // Money Flow Multiplier
      double range = ha_high[i] - ha_low[i];

      if(range > 0)
        {
         mfm = ((ha_close[i] - ha_low[i]) - (ha_high[i] - ha_close[i])) / range;
        }

      long current_volume = (InpVolumeType == VOLUME_TICK) ? tick_volume[i] : volume[i];
      double mfv = mfm * current_volume; // Money Flow Volume

      if(i > 0)
         BufferAD[i] = BufferAD[i-1] + mfv;
      else
         BufferAD[i] = mfv; // First value
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
