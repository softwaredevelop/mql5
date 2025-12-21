//+------------------------------------------------------------------+
//|                                       Gaussian_Momentum_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Optimized for incremental calculation
#property description "Gaussian-smoothed Momentum Oscillator based on Ehlers' concepts."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "G-Momentum"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLimeGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_level1 0.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\Gaussian_Filter_Calculator.mqh>

//--- Input Parameters ---
input int                       InpPeriod       = 20;    // Cutoff Period for the filter
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferMomentum[];

//--- Global calculator object ---
CGaussianFilterCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMomentum,  INDICATOR_DATA);
   ArraySetAsSeries(BufferMomentum,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CGaussianFilterCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("G-Mom HA(%d)", InpPeriod));
     }
   else
     {
      g_calculator = new CGaussianFilterCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("G-Mom(%d)", InpPeriod));
     }

// Initialize with SOURCE_MOMENTUM mode
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, SOURCE_MOMENTUM))
     {
      Print("Failed to initialize Gaussian Momentum Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
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

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

// Delegate calculation with incremental optimization
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferMomentum);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
