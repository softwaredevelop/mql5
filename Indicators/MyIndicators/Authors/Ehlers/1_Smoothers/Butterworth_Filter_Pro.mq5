//+------------------------------------------------------------------+
//|                                     Butterworth_Filter_Pro.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.10" // Upgraded with strict chronological sorting safeguards and pointer guards
#property description "John Ehlers' Higher-Order Butterworth Filter."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "Butterworth"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumPurple
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\Butterworth_Calculator.mqh>

//--- Input Parameters ---
input group                     "Butterworth Settings"
input int                       InpPeriod       = 20;              // Critical Period
input ENUM_BUTTERWORTH_POLES    InpPoles        = POLES_TWO;       // Number of poles (2 or 3)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD; // Price Source

//--- Indicator Buffers ---
double    BufferFilter[];

//--- Global calculator object ---
CButterworthCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferFilter,  INDICATOR_DATA);
   ArraySetAsSeries(BufferFilter,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CButterworthCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Butterworth HA(%d,%d)", InpPeriod, (int)InpPoles));
     }
   else
     {
      g_calculator = new CButterworthCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Butterworth(%d,%d)", InpPeriod, (int)InpPoles));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpPoles, SOURCE_PRICE))
     {
      Print("Failed to initialize Butterworth Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 3);
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
   if(rates_total < 4)
      return 0;

   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

//--- Force strict chronological indexing for state-safety on input price arrays
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Delegate calculation with prev_calculated optimization
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferFilter);

   return(rates_total);
  }
//+------------------------------------------------------------------+
