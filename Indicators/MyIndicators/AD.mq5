//+------------------------------------------------------------------+
//|                                                           AD.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.01" // Corrected volume source handling
#property description "Accumulation/Distribution Line"

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_label1  "A/D"

//--- Input Parameters ---
input ENUM_APPLIED_VOLUME InpVolumeType = VOLUME_TICK; // Volume type

//--- Indicator Buffers ---
double    BufferAD[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
void OnInit()
  {
   SetIndexBuffer(0, BufferAD, INDICATOR_DATA);
   ArraySetAsSeries(BufferAD, false);

   IndicatorSetInteger(INDICATOR_DIGITS, 0);
   IndicatorSetString(INDICATOR_SHORTNAME, "A/D");
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);
  }

//+------------------------------------------------------------------+
//| Accumulation/Distribution calculation function.                  |
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

//--- Main calculation loop
   for(int i = 0; i < rates_total; i++)
     {
      double mfm = 0; // Money Flow Multiplier
      double range = high[i] - low[i];

      if(range > 0)
        {
         mfm = ((close[i] - low[i]) - (high[i] - close[i])) / range;
        }

      // --- FIX: Use ternary operator to select volume source ---
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
