//+------------------------------------------------------------------+
//|                                         MACD_Chart_Overlay.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Overlays the two Moving Averages used by the MACD."
#property description "Visualizes the Fast and Slow components directly on the price chart."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Fast MA
#property indicator_label1  "Fast MA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Slow MA
#property indicator_label2  "Slow MA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrFireBrick
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Input Parameters
input int                       InpFastPeriod   = 12;
input int                       InpSlowPeriod   = 26;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;
input ENUM_MA_TYPE              InpSourceMAType = EMA; // MA Type for both lines

//--- Buffers
double    BufferFastMA[];
double    BufferSlowMA[];

//--- Global calculator objects
CMovingAverageCalculator *g_fast_calc;
CMovingAverageCalculator *g_slow_calc;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferFastMA, INDICATOR_DATA);
   SetIndexBuffer(1, BufferSlowMA, INDICATOR_DATA);

   ArraySetAsSeries(BufferFastMA, false);
   ArraySetAsSeries(BufferSlowMA, false);

//--- Determine actual Fast/Slow periods (just in case user swaps them)
   int fast_p = MathMin(InpFastPeriod, InpSlowPeriod);
   int slow_p = MathMax(InpFastPeriod, InpSlowPeriod);

//--- Factory Logic
   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_fast_calc = new CMovingAverageCalculator_HA();
      g_slow_calc = new CMovingAverageCalculator_HA();

      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MACD Overlay HA(%d, %d, %s)", fast_p, slow_p, EnumToString(InpSourceMAType)));
     }
   else
     {
      g_fast_calc = new CMovingAverageCalculator();
      g_slow_calc = new CMovingAverageCalculator();

      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MACD Overlay(%d, %d, %s)", fast_p, slow_p, EnumToString(InpSourceMAType)));
     }

//--- Initialize Calculators
   if(CheckPointer(g_fast_calc) == POINTER_INVALID || !g_fast_calc.Init(fast_p, InpSourceMAType))
     {
      Print("Failed to initialize Fast MA Calculator.");
      return(INIT_FAILED);
     }

   if(CheckPointer(g_slow_calc) == POINTER_INVALID || !g_slow_calc.Init(slow_p, InpSourceMAType))
     {
      Print("Failed to initialize Slow MA Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, fast_p - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, slow_p - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_fast_calc) != POINTER_INVALID)
      delete g_fast_calc;
   if(CheckPointer(g_slow_calc) != POINTER_INVALID)
      delete g_slow_calc;
  }

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
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
   if(rates_total < 2)
      return(0);

//--- CRITICAL FIX: Reset buffers on full recalculation
   if(prev_calculated == 0)
     {
      ArrayInitialize(BufferFastMA, EMPTY_VALUE);
      ArrayInitialize(BufferSlowMA, EMPTY_VALUE);
     }

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Calculate Fast MA
   g_fast_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferFastMA);

//--- Calculate Slow MA
   g_slow_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferSlowMA);

   return(rates_total);
  }
//+------------------------------------------------------------------+
