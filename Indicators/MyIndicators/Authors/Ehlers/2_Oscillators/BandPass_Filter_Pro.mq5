//+------------------------------------------------------------------+
//|                                          BandPass_Filter_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Optimized for incremental calculation
#property description "John Ehlers' Band-Pass Filter, created by combining a High-Pass"
#property description "filter with a SuperSmoother filter."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "BandPass"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_level1 0.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\BandPass_Calculator.mqh>

//--- Input Parameters ---
input int                       InpLowerPeriod  = 30;    // Lower critical period (High-Pass Cutoff)
input int                       InpUpperPeriod  = 15;    // Upper critical period (Low-Pass Cutoff)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferBandPass[];

//--- Global calculator object ---
CBandPassCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferBandPass,  INDICATOR_DATA);
   ArraySetAsSeries(BufferBandPass,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CBandPassCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("BandPass HA(%d,%d)", InpLowerPeriod, InpUpperPeriod));
     }
   else
     {
      g_calculator = new CBandPassCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("BandPass(%d,%d)", InpLowerPeriod, InpUpperPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpLowerPeriod, InpUpperPeriod))
     {
      Print("Failed to initialize Band-Pass Filter Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 10);
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
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferBandPass);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
