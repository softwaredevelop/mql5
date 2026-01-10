//+------------------------------------------------------------------+
//|                                          MADH_Chart_Overlay.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Refactored to use Windowed_MA_Calculator
#property description "Overlays the two Hann-Windowed Moving Averages used by MADH."
#property description "Uses the shared Windowed_MA_Calculator engine."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Fast HWMA
#property indicator_label1  "Fast HWMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Slow HWMA
#property indicator_label2  "Slow HWMA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrFireBrick
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\Windowed_MA_Calculator.mqh>

//--- Inputs (Must match your MADH_Pro settings)
input int                       InpShortLength    = 8;               // Short HWMA Length
input int                       InpDominantCycle  = 27;              // Dominant Cycle Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD; // Price Source

//--- Buffers
double    BufferFast[];
double    BufferSlow[];

//--- Global calculator objects
CWindowedMACalculator *g_fast_calc;
CWindowedMACalculator *g_slow_calc;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferFast, INDICATOR_DATA);
   SetIndexBuffer(1, BufferSlow, INDICATOR_DATA);

   ArraySetAsSeries(BufferFast, false);
   ArraySetAsSeries(BufferSlow, false);

// Calculate the length of the slow MA based on Ehlers' formula
   int long_len = InpShortLength + (int)round(InpDominantCycle / 2.0);

// Initialize Calculators (Standard or Heikin Ashi)
   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_fast_calc = new CWindowedMACalculator_HA();
      g_slow_calc = new CWindowedMACalculator_HA();

      string short_name = StringFormat("MADH Overlay HA(%d, %d)", InpShortLength, InpDominantCycle);
      IndicatorSetString(INDICATOR_SHORTNAME, short_name);
     }
   else
     {
      g_fast_calc = new CWindowedMACalculator();
      g_slow_calc = new CWindowedMACalculator();

      string short_name = StringFormat("MADH Overlay(%d, %d)", InpShortLength, InpDominantCycle);
      IndicatorSetString(INDICATOR_SHORTNAME, short_name);
     }

// Init Fast Calculator
   if(CheckPointer(g_fast_calc) == POINTER_INVALID || !g_fast_calc.Init(InpShortLength, SOURCE_PRICE))
     {
      Print("Failed to initialize Fast HWMA Calculator.");
      return(INIT_FAILED);
     }

// Init Slow Calculator
   if(CheckPointer(g_slow_calc) == POINTER_INVALID || !g_slow_calc.Init(long_len, SOURCE_PRICE))
     {
      Print("Failed to initialize Slow HWMA Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpShortLength - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, long_len - 1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_fast_calc) != POINTER_INVALID)
      delete g_fast_calc;
   if(CheckPointer(g_slow_calc) != POINTER_INVALID)
      delete g_slow_calc;
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
   if(CheckPointer(g_fast_calc) == POINTER_INVALID || CheckPointer(g_slow_calc) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

// Calculate Fast HWMA
   g_fast_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferFast);

// Calculate Slow HWMA
   g_slow_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferSlow);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
