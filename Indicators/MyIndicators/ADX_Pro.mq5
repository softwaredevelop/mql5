//+------------------------------------------------------------------+
//|                                                       ADX_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2025, xxxxxxxx"
#property link        ""
#property version     "2.01" // Corrected calculator logic
#property description "Professional ADX by Welles Wilder with selectable"
#property description "candle source (Standard or Heikin Ashi)."

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_buffers 3 // Only plotting buffers are needed here
#property indicator_plots   3
#property indicator_level1 25.0
#property indicator_level2 40.0
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: ADX line (Main trend strength)
#property indicator_label1  "ADX"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: +DI line (Positive Directional Indicator)
#property indicator_label2  "+DI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOliveDrab
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Plot 3: -DI line (Negative Directional Indicator)
#property indicator_label3  "-DI"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrTomato
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- Include the calculator engine ---
#include <MyIncludes\ADX_Calculator.mqh>

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input int                InpPeriodADX    = 14;              // Period for ADX calculations
input ENUM_CANDLE_SOURCE InpCandleSource = CANDLE_STANDARD; // Candle source

//--- Indicator Buffers ---
double    BufferADX[];
double    BufferPDI[];
double    BufferNDI[];

//--- Global calculator object (as a base class pointer) ---
CADXCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the buffers
   SetIndexBuffer(0, BufferADX, INDICATOR_DATA);
   SetIndexBuffer(1, BufferPDI, INDICATOR_DATA);
   SetIndexBuffer(2, BufferNDI, INDICATOR_DATA);

//--- Set all buffers as non-timeseries for stable calculation
   ArraySetAsSeries(BufferADX, false);
   ArraySetAsSeries(BufferPDI, false);
   ArraySetAsSeries(BufferNDI, false);

//--- Dynamically create the appropriate calculator instance
   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CADXCalculator_HA();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ADX Pro HA(%d)", InpPeriodADX));
         break;
      default: // CANDLE_STANDARD
         g_calculator = new CADXCalculator();
         IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ADX Pro(%d)", InpPeriodADX));
         break;
     }

//--- Check if creation was successful and initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriodADX))
     {
      Print("Failed to create or initialize ADX Calculator object.");
      return(INIT_FAILED);
     }

//--- Set indicator properties
   int period = g_calculator.GetPeriod();
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, period * 2 - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, period);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, period);

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
//--- CORRECTED: Added 'open' to the call
   g_calculator.Calculate(rates_total, open, high, low, close, BufferADX, BufferPDI, BufferNDI);

//--- Return rates_total for a full recalculation, ensuring stability
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
