//+------------------------------------------------------------------+
//|                                         Ultimate_Channel_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "John Ehlers' Ultimate Channel."
#property description "Uses Ultimate Smoother for both Centerline and True Range."

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

#property indicator_label1  "Upper"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_label2  "Lower"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_label3  "Middle"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGray
#property indicator_style3  STYLE_DOT

#include <MyIncludes\Ultimate_Channel_Calculator.mqh>

//--- Input Parameters ---
input int                       InpLength       = 20;    // Centerline Length
input int                       InpSTRLength    = 20;    // Smooth True Range Length
input double                    InpMultiplier   = 1.0;   // Channel Multiplier
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferUpper[], BufferLower[], BufferMiddle[];

//--- Global calculator object ---
CUltimateChannelCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferUpper,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferLower,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferMiddle, INDICATOR_DATA);
   ArraySetAsSeries(BufferUpper, false);
   ArraySetAsSeries(BufferLower, false);
   ArraySetAsSeries(BufferMiddle, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CUltimateChannelCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Ultimate Channel HA(%d,%d,%.1f)", InpLength, InpSTRLength, InpMultiplier));
     }
   else
     {
      g_calculator = new CUltimateChannelCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Ultimate Channel(%d,%d,%.1f)", InpLength, InpSTRLength, InpMultiplier));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpLength, InpSTRLength, InpMultiplier))
     {
      Print("Failed to initialize Ultimate Channel Calculator.");
      return(INIT_FAILED);
     }

   int draw_begin = MathMax(InpLength, InpSTRLength);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, draw_begin);
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

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferUpper, BufferLower, BufferMiddle);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
