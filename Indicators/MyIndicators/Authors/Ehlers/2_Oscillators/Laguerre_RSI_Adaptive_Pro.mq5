//+------------------------------------------------------------------+
//|                                   Laguerre_RSI_Adaptive_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.20" // Optimized for incremental calculation
#property description "John Ehlers' Adaptive Laguerre RSI with an optional signal line."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_label1  "Adaptive LRSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumTurquoise
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLightCoral
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 10.0
#property indicator_level2 20.0
#property indicator_level3 50.0
#property indicator_level4 80.0
#property indicator_level5 90.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\Laguerre_RSI_Adaptive_Calculator.mqh>

enum ENUM_LRSI_DISPLAY_MODE { DISPLAY_LRSI_ONLY, DISPLAY_LRSI_AND_SIGNAL };

//--- Input Parameters ---
input group "Laguerre RSI Settings"
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

input group "Signal Line Settings"
input ENUM_LRSI_DISPLAY_MODE InpDisplayMode  = DISPLAY_LRSI_AND_SIGNAL;
input int                    InpSignalPeriod = 9;
input ENUM_MA_TYPE           InpSignalMAType = EMA;

//--- Indicator Buffers ---
double    BufferLRSI[], BufferSignal[];

//--- Global calculator object ---
CLaguerreRSIAdaptiveCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferLRSI,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferLRSI,   false);
   ArraySetAsSeries(BufferSignal, false);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CLaguerreRSIAdaptiveCalculator_HA();
   else
      g_calculator = new CLaguerreRSIAdaptiveCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpSignalPeriod, InpSignalMAType))
     {
      Print("Failed to create or initialize Adaptive Laguerre RSI Calculator object.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Adaptive LRSI%s", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : "")));
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 10);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 10 + InpSignalPeriod - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

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

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Delegate calculation with prev_calculated optimization
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferLRSI, BufferSignal);

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
//+------------------------------------------------------------------+
