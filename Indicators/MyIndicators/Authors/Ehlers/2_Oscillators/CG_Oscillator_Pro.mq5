//+------------------------------------------------------------------+
//|                                            CG_Oscillator_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.21" // Fixed indicator decimal digits rounding bug to restore high-resolution Data Window visibility
#property description "John Ehlers' Center of Gravity (CG) Oscillator."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: CG Line
#property indicator_label1  "CG"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal Line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\CG_Oscillator_Calculator.mqh>

enum ENUM_CANDLE_SOURCE
  {
   SOURCE_STANDARD,
   SOURCE_HEIKIN_ASHI
  };

//--- Input Parameters ---
input group                     "CG Settings"
input int                InpPeriod       = 10;               // Observation Period (N)
input ENUM_CANDLE_SOURCE InpSource       = SOURCE_STANDARD;  // Candle Source
input bool               InpOriginalMode = true;             // True = Ehlers' Raw (Negative), False = Center around 0.0

//--- Indicator Buffers ---
double    BufferCG[];
double    BufferSignal[];

//--- Global calculator object ---
CCGOscillatorCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferCG,     INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferCG,     false);
   ArraySetAsSeries(BufferSignal, false);

//--- Dynamically calculate and configure horizontal centerline based on selections
   double center_level = InpOriginalMode ? -(InpPeriod + 1) / 2.0 : 0.0;
   IndicatorSetInteger(INDICATOR_LEVELS, 1);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, center_level);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, STYLE_DOT);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, clrSilver);

   if(InpSource == SOURCE_HEIKIN_ASHI)
     {
      g_calculator = new CCGOscillatorCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CG HA(%d)%s", InpPeriod, InpOriginalMode ? " Orig" : " Pro"));
     }
   else
     {
      g_calculator = new CCGOscillatorCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CG(%d)%s", InpPeriod, InpOriginalMode ? " Orig" : " Pro"));
     }

// Pass the Original Mode flag to Init
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpOriginalMode))
     {
      Print("Failed to initialize CG Oscillator Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpPeriod + 1);

//--- FIXED: Set dynamic decimal digits to match symbol precision instead of hardcoded 2
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

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
   if(rates_total < InpPeriod)
      return 0;

   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

//--- Force strict chronological indexing for state-safety on input price arrays
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

   g_calculator.Calculate(rates_total, prev_calculated, PRICE_MEDIAN, open, high, low, close, BufferCG, BufferSignal);
   return(rates_total);
  }
//+------------------------------------------------------------------+
