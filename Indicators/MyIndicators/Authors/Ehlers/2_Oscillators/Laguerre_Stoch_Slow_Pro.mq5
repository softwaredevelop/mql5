//+------------------------------------------------------------------+
//|                                      Laguerre_Stoch_Slow_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Laguerre Stochastic Slow. Calculates Stochastic from Laguerre"
#property description "components (L0-L3) and applies smoothing for cleaner signals."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Slow %K
#property indicator_label1  "Slow %K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal %D
#property indicator_label2  "Signal %D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrCoral
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Levels
#property indicator_level1 10.0
#property indicator_level2 20.0
#property indicator_level3 50.0
#property indicator_level4 80.0
#property indicator_level5 90.0
#property indicator_levelstyle STYLE_DOT
#property indicator_minimum 0.0
#property indicator_maximum 100.0

#include <MyIncludes\Laguerre_Stoch_Slow_Calculator.mqh>

//--- Input Parameters
input group                     "Laguerre Settings"
input double                    InpGamma         = 0.7;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice   = PRICE_CLOSE_STD;

input group                     "Stochastic Settings"
input int                       InpSlowingPeriod = 3;   // Smoothing for Raw %K
input ENUM_MA_TYPE              InpSlowingMethod = SMA; // Method for Slowing
input int                       InpSignalPeriod  = 3;   // Signal Line Period
input ENUM_MA_TYPE              InpSignalMethod  = SMA; // Method for Signal

//--- Buffers
double    BufferSlowK[];
double    BufferSignalD[];

//--- Global Object
CLaguerreStochSlowCalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferSlowK,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignalD, INDICATOR_DATA);
   ArraySetAsSeries(BufferSlowK,   false);
   ArraySetAsSeries(BufferSignalD, false);

//--- Factory Logic
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CLaguerreStochSlowCalculator_HA();
   else
      g_calculator = new CLaguerreStochSlowCalculator();

//--- Initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpGamma, InpSlowingPeriod, InpSlowingMethod, InpSignalPeriod, InpSignalMethod))
     {
      Print("Failed to initialize Laguerre Stoch Slow Calculator.");
      return(INIT_FAILED);
     }

//--- Shortname
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Laguerre Stoch Slow%s(%.2f, %d, %d)", type, InpGamma, InpSlowingPeriod, InpSignalPeriod));

//--- Visuals
   int draw_begin = InpSlowingPeriod + InpSignalPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
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

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          BufferSlowK, BufferSignalD);

   return(rates_total);
  }
//+------------------------------------------------------------------+
