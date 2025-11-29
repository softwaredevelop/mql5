//+------------------------------------------------------------------+
//|                               Ehlers_Smoother_Momentum_Pro.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.10" // Optimized for incremental calculation
#property description "Ehlers' Smoother (Super/Ultimate) applied to Momentum (Close-Open)."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "S-Momentum"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlueViolet
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_level1 0.0
#property indicator_levelstyle STYLE_SOLID
#property indicator_levelcolor clrGray

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>

//--- Restored Enum for clarity ---
enum ENUM_CANDLE_SOURCE
  {
   SOURCE_STD, // Standard Candles
   SOURCE_HA   // Heikin Ashi Candles
  };

//--- Input Parameters ---
input ENUM_SMOOTHER_TYPE InpSmootherType = SUPERSMOOTHER;
input int                InpPeriod       = 20;
input ENUM_CANDLE_SOURCE InpCandleSource = SOURCE_STD;

//--- Indicator Buffers ---
double    BufferMomentum[];

//--- Global calculator object ---
CEhlersSmootherCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMomentum,  INDICATOR_DATA);
   ArraySetAsSeries(BufferMomentum,  false);

   string name = (InpSmootherType == SUPERSMOOTHER) ? "SS-Mom" : "US-Mom";

   if(InpCandleSource == SOURCE_HA)
     {
      g_calculator = new CEhlersSmootherCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("%s HA(%d)", name, InpPeriod));
     }
   else
     {
      g_calculator = new CEhlersSmootherCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("%s(%d)", name, InpPeriod));
     }

// Initialize with SOURCE_MOMENTUM mode
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpSmootherType, SOURCE_MOMENTUM))
     {
      Print("Failed to initialize Ehlers Smoother Momentum Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 3);
   IndicatorSetInteger(INDICATOR_DIGITS, 4);

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
//--- We pass PRICE_CLOSE as a dummy value because in SOURCE_MOMENTUM mode,
//--- the calculator ignores price_type and calculates (Close - Open) internally.
   g_calculator.Calculate(rates_total, prev_calculated, PRICE_CLOSE, open, high, low, close, BufferMomentum);

   return(rates_total);
  }
//+------------------------------------------------------------------+
