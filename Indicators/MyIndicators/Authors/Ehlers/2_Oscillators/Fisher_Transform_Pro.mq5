//+------------------------------------------------------------------+
//|                                        Fisher_Transform_Pro.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.10" // Upgraded with dynamic Signal Line options, volume translation and chronological sorting safeguards
#property description "John Ehlers' Fisher Transform for identifying sharp turning points."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_label1  "Fisher"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_level1  1.5
#property indicator_level2  0.75
#property indicator_level3  0.0
#property indicator_level4 -0.75
#property indicator_level5 -1.5
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\Fisher_Transform_Calculator.mqh>

enum ENUM_PRICE_SOURCE { SOURCE_STANDARD, SOURCE_HEIKIN_ASHI };

//--- Input Parameters ---
input group                     "Fisher Settings"
input int              InpPeriod       = 10;              // Period for price normalization
input double           InpAlpha        = 0.33;            // Smoothing factor for normalized price
input ENUM_PRICE_SOURCE InpSource      = SOURCE_STANDARD; // Price Source

input group                     "Signal Line Settings"
input ENUM_FISHER_SIGNAL_TYPE InpSignalType   = SIGNAL_DELAY_1BAR; // Signal Type
input int                     InpSignalPeriod = 5;                 // Period (if MA)
input ENUM_MA_TYPE            InpSignalMethod = SMA;               // Method (if MA / VWMA)

//--- Indicator Buffers ---
double    BufferFisher[];
double    BufferSignal[];

//--- Global calculator object ---
CFisherTransformCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferFisher, INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferFisher, false);
   ArraySetAsSeries(BufferSignal, false);

   if(InpSource == SOURCE_HEIKIN_ASHI)
     {
      g_calculator = new CFisherTransformCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Fisher HA(%d,%.2f)", InpPeriod, InpAlpha));
     }
   else
     {
      g_calculator = new CFisherTransformCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Fisher(%d,%.2f)", InpPeriod, InpAlpha));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriod, InpAlpha, InpSignalType, InpSignalPeriod, InpSignalMethod))
     {
      Print("Failed to initialize Fisher Transform Calculator.");
      return(INIT_FAILED);
     }

   int draw_begin = InpPeriod;
   int sig_begin  = (InpSignalType == SIGNAL_DELAY_1BAR) ? InpPeriod + 1 : InpPeriod + InpSignalPeriod;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, sig_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

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

//--- Determine best volume array (Use Real Volume if available, otherwise fallback to Tick Volume)
   long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

//--- Delegate calculations dynamically to support volume-weighted types (VWMA) on the Signal Line
   if(volume_limit > 0)
     {
      g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, volume, BufferFisher, BufferSignal);
     }
   else
     {
      g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, tick_volume, BufferFisher, BufferSignal);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
