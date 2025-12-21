//+------------------------------------------------------------------+
//|                               Gaussian_Momentum_Advanced_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Advanced Gaussian Momentum with optional Signal Line."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Momentum
#property indicator_label1  "Momentum"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLimeGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrTomato
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_level1 0.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\Gaussian_Momentum_Advanced_Calculator.mqh>

//--- Enums
enum ENUM_DISPLAY_MODE
  {
   DISPLAY_MOMENTUM_ONLY,
   DISPLAY_MOMENTUM_AND_SIGNAL
  };

//--- Inputs
input group                     "Momentum Settings"
input int                       InpPeriod       = 20;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

input group                     "Signal Settings"
input ENUM_DISPLAY_MODE         InpDisplayMode  = DISPLAY_MOMENTUM_AND_SIGNAL;
input int                       InpSignalPeriod = 12;
input ENUM_MA_TYPE              InpSignalMAType = SMA;

//--- Buffers
double    BufferMomentum[];
double    BufferSignal[];

//--- Calculator
CGaussianMomentumAdvancedCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMomentum, INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal,   INDICATOR_DATA);
   ArraySetAsSeries(BufferMomentum,  false);
   ArraySetAsSeries(BufferSignal,    false);

   g_calculator = new CGaussianMomentumAdvancedCalculator();

   bool use_ha = (InpSourcePrice <= PRICE_HA_CLOSE);

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriod, InpSignalPeriod, InpSignalMAType, use_ha))
     {
      return(INIT_FAILED);
     }

   string type = use_ha ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("G-Mom Adv%s(%d,%d)", type, InpPeriod, InpSignalPeriod));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 2 + InpSignalPeriod);

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

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferMomentum, BufferSignal);

// Handle Display Mode
   if(InpDisplayMode == DISPLAY_MOMENTUM_ONLY)
     {
      int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      for(int i = start; i < rates_total; i++)
         BufferSignal[i] = EMPTY_VALUE;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
