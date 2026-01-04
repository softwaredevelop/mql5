//+------------------------------------------------------------------+
//|                                              ZeroLag_EMA_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Optimized for incremental calculation
#property description "Zero-Lag Exponential Moving Average (ZLEMA). Supports standard"
#property description "and Ehlers' optimized gain (Error Correcting) modes."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "ZLEMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumTurquoise
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\ZeroLag_EMA_Calculator.mqh>

//--- Input Parameters ---
input int                       InpPeriod       = 20;    // EMA Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;
input group "Advanced Settings"
input bool                      InpOptimizeGain = false; // Use Ehlers' Error Correcting (slower)
input double                    InpGainLimit    = 5.0;   // Gain Limit for optimization (e.g., 5.0 = +/- 50 steps)

//--- Indicator Buffers ---
double    BufferZLEMA[];

//--- Global calculator object ---
CZeroLagEMACalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferZLEMA,  INDICATOR_DATA);
   ArraySetAsSeries(BufferZLEMA,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CZeroLagEMACalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ZLEMA HA(%d)", InpPeriod));
     }
   else
     {
      g_calculator = new CZeroLagEMACalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ZLEMA(%d)", InpPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpOptimizeGain, InpGainLimit))
     {
      Print("Failed to initialize Zero-Lag EMA Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod * 2);
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
int OnCalculate(const int rates_total, const int prev_calculated, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferZLEMA);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
