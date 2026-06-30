//+------------------------------------------------------------------+
//|                                             Laguerre_RSI_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.45" // Upgraded for 3-digit Gamma precision and chronological safety
#property description "John Ehlers' Laguerre RSI with an optional signal line."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Laguerre RSI Line
#property indicator_label1  "Laguerre RSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumTurquoise
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal Line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLightCoral
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Scale and Level Properties ---
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 10.0
#property indicator_level2 20.0
#property indicator_level3 50.0
#property indicator_level4 80.0
#property indicator_level5 90.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\Laguerre_RSI_Calculator.mqh>

//--- Enum for Display Mode ---
enum ENUM_LRSI_DISPLAY_MODE
  {
   DISPLAY_LRSI_ONLY,
   DISPLAY_LRSI_AND_SIGNAL
  };

//--- Input Parameters ---
input group "Laguerre RSI Settings"
input double                    InpGamma        = 0.5;             // Gamma (e.g. 0.236, 0.382, 0.500)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD; // Price Source

input group "Signal Line Settings"
input ENUM_LRSI_DISPLAY_MODE InpDisplayMode  = DISPLAY_LRSI_AND_SIGNAL; // Display Mode
input int                    InpSignalPeriod = 3;                       // Period (if MA)
input ENUM_MA_TYPE           InpSignalMAType = EMA;                     // MA Type

//--- Indicator Buffers ---
double    BufferLRSI[], BufferSignal[];

//--- Global calculator object ---
CLaguerreRSICalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferLRSI,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferLRSI,   false);
   ArraySetAsSeries(BufferSignal, false);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CLaguerreRSICalculator_HA();
   else
      g_calculator = new CLaguerreRSICalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpGamma, InpSignalPeriod, InpSignalMAType))
     {
      Print("Failed to create or initialize Laguerre RSI Calculator object.");
      return(INIT_FAILED);
     }

//--- Updated format string to %.3f to support exact Fibonacci decimals
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Laguerre RSI%s(%.3f)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpGamma));
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 2 + InpSignalPeriod - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

//+------------------------------------------------------------------+
//| Custom indicator calculation function                            |
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

//--- Force strict chronological indexing for state-safety on input price arrays
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Determine best volume array (Use Real Volume if available, otherwise fallback to Tick Volume)
   long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

//--- Delegate calculations dynamically to support volume-weighted types (VWMA) on the Signal Line
   if(volume_limit > 0)
     {
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, volume, BufferLRSI, BufferSignal);
     }
   else
     {
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, tick_volume, BufferLRSI, BufferSignal);
     }

//--- Hide Signal if needed (Optimized loop)
   if(InpDisplayMode == DISPLAY_LRSI_ONLY)
     {
      int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      for(int i = start_index; i < rates_total; i++)
         BufferSignal[i] = EMPTY_VALUE;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
