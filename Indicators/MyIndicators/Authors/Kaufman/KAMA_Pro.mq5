//+------------------------------------------------------------------+
//|                                                      KAMA_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.10" // Optimized for incremental calculation
#property description "Perry Kaufman's Adaptive Moving Average (KAMA)."
#property description "Adapts its speed based on market volatility."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "KAMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\KAMA_Calculator.mqh>

//--- Input Parameters ---
input int                       InpErPeriod       = 10;    // Efficiency Ratio Period
input int                       InpFastEmaPeriod  = 2;     // Fastest EMA Period
input int                       InpSlowEmaPeriod  = 30;    // Slowest EMA Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferKAMA[];

//--- Global calculator object ---
CKamaCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferKAMA,  INDICATOR_DATA);
   ArraySetAsSeries(BufferKAMA,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CKamaCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("KAMA HA(%d,%d,%d)", InpErPeriod, InpFastEmaPeriod, InpSlowEmaPeriod));
     }
   else
     {
      g_calculator = new CKamaCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("KAMA(%d,%d,%d)", InpErPeriod, InpFastEmaPeriod, InpSlowEmaPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpErPeriod, InpFastEmaPeriod, InpSlowEmaPeriod))
     {
      Print("Failed to initialize KAMA Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpErPeriod);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

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

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Delegate calculation with prev_calculated optimization
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferKAMA);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
