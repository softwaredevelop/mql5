//+------------------------------------------------------------------+
//|                                              Windowed_MA_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Refactored to Hann-only, incremental
#property description "Hann Windowed Moving Average (FIR Filter)."
#property description "A smooth, zero-lag filter using cosine-weighted averaging."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "Hann MA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\Windowed_MA_Calculator.mqh>

//--- Input Parameters ---
// REMOVED: InpWindowType (Only Hann is supported now)
input int                       InpPeriod      = 20;            // Averaging Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD; // Price type for calculation

//--- Indicator Buffers ---
double    BufferOutput[];

//--- Global calculator object ---
CWindowedMACalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferOutput,  INDICATOR_DATA);
   ArraySetAsSeries(BufferOutput,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CWindowedMACalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Hann MA HA(%d)", InpPeriod));
     }
   else
     {
      g_calculator = new CWindowedMACalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Hann MA(%d)", InpPeriod));
     }

// Initialize the calculator in PRICE mode
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, SOURCE_PRICE))
     {
      Print("Failed to initialize Windowed MA Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod - 1);
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
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferOutput);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
