//+------------------------------------------------------------------+
//|                                                    VWAP_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.11" // Added plot labels for clarity
#property description "Volume Weighted Average Price (VWAP) with selectable reset period"
#property description "and candle source (Standard or Heikin Ashi)."

#property indicator_chart_window
#property indicator_buffers 2 // Two buffers for gapped drawing
#property indicator_plots   2

//--- Include the calculator engine ---
#include <MyIncludes\VWAP_Calculator.mqh>

//--- Plot 1: VWAP Line (Odd Periods)
#property indicator_label1  "VWAP" // This label is shown on the chart
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrOrange
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: VWAP Line (Even Periods)
#property indicator_label2  "" // No label on the chart for the second part
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input ENUM_VWAP_PERIOD    InpResetPeriod  = PERIOD_SESSION; // Reset Period
input ENUM_APPLIED_VOLUME InpVolumeType   = VOLUME_TICK;    // Volume Type
input ENUM_CANDLE_SOURCE  InpCandleSource = CANDLE_STANDARD;  // Candle Source

//--- Indicator Buffers ---
double    BufferVWAP_Odd[];
double    BufferVWAP_Even[];

//--- Global calculator object (as a base class pointer) ---
CVWAPCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferVWAP_Odd,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferVWAP_Even, INDICATOR_DATA);
   ArraySetAsSeries(BufferVWAP_Odd,  false);
   ArraySetAsSeries(BufferVWAP_Even, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
     {
      g_calculator = new CVWAPCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, "VWAP HA");
      // Set labels for Data Window and Properties
      PlotIndexSetString(0, PLOT_LABEL, "VWAP HA");
      PlotIndexSetString(1, PLOT_LABEL, "VWAP HA (Segment)");
     }
   else
     {
      g_calculator = new CVWAPCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, "VWAP");
      // Set labels for Data Window and Properties
      PlotIndexSetString(0, PLOT_LABEL, "VWAP");
      PlotIndexSetString(1, PLOT_LABEL, "VWAP (Segment)");
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpResetPeriod, InpVolumeType))
     {
      Print("Failed to create or initialize VWAP Calculator object.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 1);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation function.                           |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime& time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;
   g_calculator.Calculate(rates_total, time, open, high, low, close, tick_volume, volume, BufferVWAP_Odd, BufferVWAP_Even);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
