//+------------------------------------------------------------------+
//|                                                       MFI_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "3.02" // Added selectable display mode for signal line
#property description "Professional Money Flow Index (MFI) with an optional signal line and"
#property description "selectable candle source (Standard or Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 2 // MFI and Signal Line
#property indicator_plots   2
#property indicator_maximum 100.0
#property indicator_minimum 0.0
#property indicator_level1  20.0
#property indicator_level2  80.0
#property indicator_level3  50.0
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: MFI line
#property indicator_label1  "MFI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Include the calculator engine ---
#include <MyIncludes\MFI_Calculator.mqh>

//--- Enum for Display Mode ---
enum ENUM_DISPLAY_MODE
  {
   DISPLAY_MFI_ONLY,       // Display only the MFI line
   DISPLAY_MFI_AND_SIGNAL  // Display MFI and its signal line
  };

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input int                 InpMFIPeriod    = 14;
input ENUM_CANDLE_SOURCE  InpCandleSource = CANDLE_STANDARD;
input ENUM_APPLIED_VOLUME InpVolumeType   = VOLUME_TICK;
input group               "Signal Line Settings"
input ENUM_DISPLAY_MODE   InpDisplayMode  = DISPLAY_MFI_AND_SIGNAL;
input int                 InpMAPeriod     = 9;
input ENUM_MA_METHOD      InpMAMethod     = MODE_SMA;

//--- Indicator Buffers ---
double    BufferMFI[];
double    BufferSignal[];

//--- Global calculator object (as a base class pointer) ---
CMFICalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the buffers and set as non-timeseries
   SetIndexBuffer(0, BufferMFI,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferMFI,    false);
   ArraySetAsSeries(BufferSignal, false);

//--- Dynamically create the appropriate calculator instance
   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CMFICalculator_HA();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MFI HA(%d,%d)", InpMFIPeriod, InpMAPeriod));
         break;
      default: // CANDLE_STANDARD
         g_calculator = new CMFICalculator();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MFI(%d,%d)", InpMFIPeriod, InpMAPeriod));
         break;
     }

//--- Check if creation was successful and initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpMFIPeriod, InpMAPeriod, InpMAMethod, InpVolumeType))
     {
      Print("Failed to create or initialize MFI Calculator object.");
      return(INIT_FAILED);
     }

//--- Set indicator display properties
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpMFIPeriod);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpMFIPeriod + InpMAPeriod - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Free the calculator object to prevent memory leaks
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation function.                           |
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
//--- Ensure the calculator object is valid
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

//--- Delegate the entire calculation to our calculator object
   g_calculator.Calculate(rates_total, open, high, low, close, tick_volume, volume, BufferMFI, BufferSignal);

//--- Hide signal line buffer if not needed
   if(InpDisplayMode == DISPLAY_MFI_ONLY)
     {
      for(int i = 0; i < rates_total; i++)
        {
         BufferSignal[i] = EMPTY_VALUE;
        }
     }

//--- Return rates_total for a full recalculation, ensuring stability
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
