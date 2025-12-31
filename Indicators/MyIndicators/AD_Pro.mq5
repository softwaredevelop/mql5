//+------------------------------------------------------------------+
//|                                                       AD_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Optimized for incremental calculation
#property description "Professional Accumulation/Distribution Line with selectable"
#property description "candle source (Standard or Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_label1  "A/D"

//--- Include the calculator engine ---
#include <MyIncludes\AD_Calculator.mqh>

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input ENUM_CANDLE_SOURCE  InpCandleSource = CANDLE_STANDARD; // Candle source
input ENUM_APPLIED_VOLUME InpVolumeType   = VOLUME_TICK;     // Volume type

//--- Indicator Buffers ---
double    BufferAD[];

//--- Global calculator object ---
CADCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferAD, INDICATOR_DATA);
   ArraySetAsSeries(BufferAD, false);

   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CADCalculator_HA();
         IndicatorSetString(INDICATOR_SHORTNAME, "HA A/D");
         break;
      default:
         g_calculator = new CADCalculator();
         IndicatorSetString(INDICATOR_SHORTNAME, "A/D");
         break;
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID)
     {
      Print("Failed to create A/D Calculator object.");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, 0);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

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
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Delegate calculation with incremental optimization
   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, tick_volume, volume, InpVolumeType, BufferAD);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
