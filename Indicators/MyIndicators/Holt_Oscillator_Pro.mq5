//+------------------------------------------------------------------+
//|                                           Holt_Oscillator_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.00" // Refactored to use Holt Engine
#property description "Holt's Trend Oscillator. Shows the smoothed trend component."
#property description "Supports Standard and Heikin Ashi price sources."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_level1 0.0
#property indicator_levelstyle STYLE_DOT
#property indicator_levelcolor clrGray

//--- Include the calculator engine ---
#include <MyIncludes\Holt_Oscillator_Calculator.mqh>

//--- Plot 1: Holt Trend Oscillator
#property indicator_label1  "Holt Trend"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSeaGreen, clrTomato
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input double                    InpAlpha       = 0.1;     // Level Smoothing Factor (0.0 - 1.0)
input double                    InpBeta        = 0.05;    // Trend Smoothing Factor (0.0 - 1.0)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferOscillator[];

//--- Global calculator object ---
CHoltOscillatorCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferOscillator, INDICATOR_DATA);
   ArraySetAsSeries(BufferOscillator, false);

   g_calculator = new CHoltOscillatorCalculator();

   bool use_ha = (InpSourcePrice <= PRICE_HA_CLOSE);

// Pass 0 for period as it is ignored by the engine
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(0, InpAlpha, InpBeta, use_ha))
     {
      Print("Failed to initialize Holt Oscillator Calculator.");
      return(INIT_FAILED);
     }

   string type = use_ha ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Holt Osc%s(%.2f, %.2f)", type, InpAlpha, InpBeta));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits+2);

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

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferOscillator);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
