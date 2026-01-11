//+------------------------------------------------------------------+
//|                                                  Gann_HiLo_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "4.00" // Refactored to use MovingAverage_Engine
#property description "Professional Gann HiLo Activator with selectable MA and"
#property description "candle source (Standard or Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Plot 1: Gann HiLo line
#property indicator_label1  "Gann_HiLo"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrMediumSeaGreen, clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\GannHiLo_Calculator.mqh>

enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,
   CANDLE_HEIKIN_ASHI
  };

//--- Input Parameters ---
input int                InpPeriod       = 10;              // Period for High/Low averages
// UPDATED: Use ENUM_MA_TYPE instead of ENUM_MA_METHOD
input ENUM_MA_TYPE       InpMAMethod     = SMA;             // Method for High/Low averages
input ENUM_CANDLE_SOURCE InpCandleSource = CANDLE_STANDARD; // Candle source

//--- Indicator Buffers ---
double    BufferGannHiLo[];
double    BufferColor[];

//--- Global calculator object ---
CGannHiLoCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferGannHiLo, INDICATOR_DATA);
   SetIndexBuffer(1, BufferColor,    INDICATOR_COLOR_INDEX);
   ArraySetAsSeries(BufferGannHiLo, false);
   ArraySetAsSeries(BufferColor,    false);

   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CGannHiLoCalculator_HA();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("GannHiLo HA(%d)", InpPeriod));
         break;
      default:
         g_calculator = new CGannHiLoCalculator();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("GannHiLo(%d)", InpPeriod));
         break;
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpMAMethod))
     {
      Print("Failed to create or initialize Gann HiLo Calculator object.");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod);

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

   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferGannHiLo, BufferColor);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
