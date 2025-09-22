//+------------------------------------------------------------------+
//|                                             Holt_Oscillator.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00"
#property description "Holt's Trend Oscillator. Shows the smoothed trend component."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_level1 0.0
#property indicator_levelstyle STYLE_DOT
#property indicator_levelcolor clrGray

#include <MyIncludes\Holt_Calculator.mqh>

//--- Plot 1: Holt Trend Oscillator
#property indicator_label1  "Holt Trend"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSeaGreen, clrTomato
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int              InpPeriod      = 20;
input double           InpAlpha       = 0.1;
input double           InpBeta        = 0.05;
input ENUM_APPLIED_PRICE InpSourcePrice = PRICE_CLOSE;

//--- Indicator Buffers ---
double    BufferOscillator[];

//--- Global calculator object ---
CHoltMACalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferOscillator, INDICATOR_DATA);
   ArraySetAsSeries(BufferOscillator, false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Holt Osc(%d, %.2f, %.2f)", InpPeriod, InpAlpha, InpBeta));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits+2);

   g_calculator = new CHoltMACalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpAlpha, InpBeta))
     {
      Print("Failed to initialize Holt MA Calculator.");
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function.                             |
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
   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      double dummy_forecast[];
      g_calculator.Calculate(rates_total, InpSourcePrice, open, high, low, close, dummy_forecast, BufferOscillator);
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
