//+------------------------------------------------------------------+
//|                                                       CHO_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.00" // Refactored to use MovingAverage_Engine
#property description "Professional Chaikin Oscillator (CHO) with selectable MA type and"
#property description "candle source (Standard or Heikin Ashi) for the underlying ADL."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_label1  "CHO"
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

//--- Include the calculator engine ---
#include <MyIncludes\CHO_Calculator.mqh>

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input int                 InpFastPeriod   = 3;
input int                 InpSlowPeriod   = 10;
// UPDATED: Use ENUM_MA_TYPE
input ENUM_MA_TYPE        InpMaMethod     = EMA;
input ENUM_APPLIED_VOLUME InpVolumeType   = VOLUME_TICK;
input ENUM_CANDLE_SOURCE  InpCandleSource = CANDLE_STANDARD; // Candle source for ADL

//--- Indicator Buffers ---
double    BufferCHO[];

//--- Global calculator object ---
CCHOCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferCHO, INDICATOR_DATA);
   ArraySetAsSeries(BufferCHO, false);

   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CCHOCalculator_HA();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CHO HA(%d,%d,%s)", InpFastPeriod, InpSlowPeriod, EnumToString(InpMaMethod)));
         break;
      default:
         g_calculator = new CCHOCalculator_Std();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CHO(%d,%d,%s)", InpFastPeriod, InpSlowPeriod, EnumToString(InpMaMethod)));
         break;
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpFastPeriod, InpSlowPeriod, InpMaMethod, InpVolumeType))
     {
      Print("Failed to create or initialize CHO Calculator object.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_calculator.GetSlowPeriod() - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, 0);

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
   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, tick_volume, volume, InpVolumeType, BufferCHO);

   return(rates_total);
  }
//+------------------------------------------------------------------+
