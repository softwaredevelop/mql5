//+------------------------------------------------------------------+
//|                                                       SMI_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.01" // Optimized for incremental calculation
#property description "Professional Stochastic Momentum Index (SMI) with a signal line and"
#property description "selectable candle source (Standard or Heikin Ashi)."

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_buffers 2 // SMI and Signal Line
#property indicator_plots   2
#property indicator_level1  80.0
#property indicator_level2  60.0
#property indicator_level3  40.0
#property indicator_level4  0.0
#property indicator_level5 -40.0
#property indicator_level6 -60.0
#property indicator_level7 -80.0
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: SMI line
#property indicator_label1  "SMI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSteelBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDarkOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Include the calculator engine ---
#include <MyIncludes\SMI_Calculator.mqh>

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input int                InpLengthK      = 10; // %K Length
input int                InpLengthD      = 3;  // %D Length (for double smoothing)
input int                InpLengthEMA    = 3;  // EMA Length (for signal line)
input ENUM_CANDLE_SOURCE InpCandleSource = CANDLE_STANDARD;

//--- Indicator Buffers ---
double    BufferSMI[];
double    BufferSignal[];

//--- Global calculator object (as a base class pointer) ---
CSMICalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the buffers and set as non-timeseries
   SetIndexBuffer(0, BufferSMI,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferSMI,    false);
   ArraySetAsSeries(BufferSignal, false);

//--- Dynamically create the appropriate calculator instance
   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CSMICalculator_HA();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("SMI HA(%d,%d,%d)", InpLengthK, InpLengthD, InpLengthEMA));
         break;
      default: // CANDLE_STANDARD
         g_calculator = new CSMICalculator();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("SMI(%d,%d,%d)", InpLengthK, InpLengthD, InpLengthEMA));
         break;
     }

//--- Check if creation was successful and initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpLengthK, InpLengthD, InpLengthEMA))
     {
      Print("Failed to create or initialize SMI Calculator object.");
      return(INIT_FAILED);
     }

//--- Set indicator display properties
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   int smi_draw_begin = InpLengthK + InpLengthD + InpLengthD - 3;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, smi_draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, smi_draw_begin + InpLengthEMA - 1);

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
                const int prev_calculated, // <--- Now used!
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

//--- Delegate calculation with prev_calculated optimization
   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close,
                          BufferSMI, BufferSignal);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
