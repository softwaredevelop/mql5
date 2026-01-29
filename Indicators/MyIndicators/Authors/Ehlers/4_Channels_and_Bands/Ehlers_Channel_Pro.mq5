//+------------------------------------------------------------------+
//|                                           Ehlers_Channel_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Ehlers Channel (Keltner Concept): Super/Ultimate Smoother Middle Line + ATR Bands."

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Plot 1: Upper Band
#property indicator_label1  "Upper Band"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumSlateBlue
#property indicator_style1  STYLE_DOT
#property indicator_width1  1

//--- Plot 2: Lower Band
#property indicator_label2  "Lower Band"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrMediumSlateBlue
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Plot 3: Middle Band (Smoother)
#property indicator_label3  "Smoother"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCrimson
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#include <MyIncludes\Ehlers_Channel_Calculator.mqh>

//--- Input Parameters
input group                     "Smoother Settings"
input ENUM_SMOOTHER_TYPE        InpSmootherType   = SUPERSMOOTHER; // Filter Type
input int                       InpPeriod         = 20;            // Filter Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group                     "Channel (ATR) Settings"
input int                       InpAtrPeriod      = 14;
input double                    InpMultiplier     = 2.0;
input ENUM_ATR_SOURCE           InpAtrSource      = ATR_SOURCE_STANDARD;

//--- Buffers
double    BufferUpper[];
double    BufferLower[];
double    BufferMiddle[];

//--- Global Object
CEhlersChannelCalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferUpper,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferLower,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferMiddle, INDICATOR_DATA);
   ArraySetAsSeries(BufferUpper,  false);
   ArraySetAsSeries(BufferLower,  false);
   ArraySetAsSeries(BufferMiddle, false);

//--- Factory Logic
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CEhlersChannelCalculator_HA();
   else
      g_calculator = new CEhlersChannelCalculator();

//--- Initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriod, InpSmootherType, InpAtrPeriod, InpMultiplier, InpAtrSource))
     {
      Print("Failed to initialize Ehlers Channel Calculator.");
      return(INIT_FAILED);
     }

//--- Shortname
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string smoothStr = (InpSmootherType == SUPERSMOOTHER) ? "SS" : "US";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Ehlers Ch%s(%s %d, ATR %d)", type, smoothStr, InpPeriod, InpAtrPeriod));

//--- Visuals
   int draw_begin = MathMax(InpPeriod, InpAtrPeriod);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, 2); // Smoother warms up fast
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

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
   if(rates_total < MathMax(InpPeriod, InpAtrPeriod))
      return(0);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, price_type,
                          BufferMiddle, BufferUpper, BufferLower);

   return(rates_total);
  }
//+------------------------------------------------------------------+
