//+------------------------------------------------------------------+
//|                                                  Gann_HiLo_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.10" // Optimized for incremental calculation
#property description "Professional Gann HiLo Activator with selectable MA and"
#property description "candle source (Standard or Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 2 // Main line and color buffer
#property indicator_plots   1

//--- Plot 1: Gann HiLo line
#property indicator_label1  "Gann_HiLo"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrMediumSeaGreen, clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Include the calculator engine ---
#include <MyIncludes\GannHiLo_Calculator.mqh>

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input int                InpPeriod       = 10;              // Period for High/Low averages
input ENUM_MA_METHOD     InpMAMethod     = MODE_SMA;        // Method for High/Low averages
input ENUM_CANDLE_SOURCE InpCandleSource = CANDLE_STANDARD; // Candle source

//--- Indicator Buffers ---
double    BufferGannHiLo[];
double    BufferColor[];

//--- Global calculator object (as a base class pointer) ---
CGannHiLoCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the buffers and set as non-timeseries
   SetIndexBuffer(0, BufferGannHiLo, INDICATOR_DATA);
   SetIndexBuffer(1, BufferColor,    INDICATOR_COLOR_INDEX);
   ArraySetAsSeries(BufferGannHiLo, false);
   ArraySetAsSeries(BufferColor,    false);

//--- Dynamically create the appropriate calculator instance
   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CGannHiLoCalculator_HA();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("GannHiLo HA(%d)", InpPeriod));
         break;
      default: // CANDLE_STANDARD
         g_calculator = new CGannHiLoCalculator();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("GannHiLo(%d)", InpPeriod));
         break;
     }

//--- Check if creation was successful and initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpMAMethod))
     {
      Print("Failed to create or initialize Gann HiLo Calculator object.");
      return(INIT_FAILED);
     }

//--- Set indicator display properties
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod);

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
//| Custom indicator calculation function                            |
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
// Note: We pass 'open' array even though base calc doesn't use it, but HA calc does.
   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferGannHiLo, BufferColor);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
