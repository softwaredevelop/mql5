//+------------------------------------------------------------------+
//|                                                 CutlerRSI_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.10" // Refactored to use MovingAverage_Engine
#property description "Professional Cutler's RSI (SMA-based) with an optional signal line and"
#property description "selectable price source (Standard and Heikin Ashi)."

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 30.0
#property indicator_level2 50.0
#property indicator_level3 70.0

//--- Buffers and Plots ---
#property indicator_buffers 2 // CutlerRSI and its MA
#property indicator_plots   2

//--- Plot 1: Cutler's RSI line (raw)
#property indicator_label1  "Cutler's RSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: MA line (smoothed)
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Include the calculator engine ---
#include <MyIncludes\CutlerRSI_Calculator.mqh>

//--- Enum for Display Mode ---
enum ENUM_DISPLAY_MODE
  {
   DISPLAY_RSI_ONLY,       // Display only the RSI line
   DISPLAY_RSI_AND_SIGNAL  // Display RSI and its signal line
  };

//--- Input Parameters ---
input int                       InpPeriodRSI    = 14;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;
input group                     "Signal Line Settings"
input ENUM_DISPLAY_MODE         InpDisplayMode  = DISPLAY_RSI_AND_SIGNAL;
input int                       InpPeriodMA     = 14;
// UPDATED: Use ENUM_MA_TYPE
input ENUM_MA_TYPE              InpMethodMA     = SMA;

//--- Indicator Buffers ---
double    BufferCutlerRSI[];
double    BufferSignalMA[];

//--- Global calculator object ---
CCutlerRSICalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferCutlerRSI, INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignalMA,  INDICATOR_DATA);
   ArraySetAsSeries(BufferCutlerRSI, false);
   ArraySetAsSeries(BufferSignalMA,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CCutlerRSICalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CutlerRSI HA(%d,%d)", InpPeriodRSI, InpPeriodMA));
     }
   else
     {
      g_calculator = new CCutlerRSICalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CutlerRSI(%d,%d)", InpPeriodRSI, InpPeriodMA));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriodRSI, InpPeriodMA, InpMethodMA))
     {
      Print("Failed to create or initialize CutlerRSI Calculator object.");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriodRSI);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpPeriodRSI + InpPeriodMA - 1);

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

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferCutlerRSI, BufferSignalMA);

   if(InpDisplayMode == DISPLAY_RSI_ONLY)
     {
      int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      for(int i = start; i < rates_total; i++)
         BufferSignalMA[i] = EMPTY_VALUE;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
