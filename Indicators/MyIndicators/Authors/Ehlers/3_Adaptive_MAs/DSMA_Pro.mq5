//+------------------------------------------------------------------+
//|                                                     DSMA_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Optimized for incremental calculation
#property description "John Ehlers' DSMA (Deviation Scaled Moving Average)."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "DSMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrNavy
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\DSMA_Calculator.mqh>

//--- Input Parameters ---
input int                       InpPeriod       = 40;    // Critical Period for the filter
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferDSMA[];

//--- Global calculator object ---
CDSMACalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferDSMA,  INDICATOR_DATA);
   ArraySetAsSeries(BufferDSMA,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CDSMACalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("DSMA HA(%d)", InpPeriod));
     }
   else
     {
      g_calculator = new CDSMACalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("DSMA(%d)", InpPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod))
     {
      Print("Failed to initialize DSMA Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod + 2);
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

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferDSMA);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
