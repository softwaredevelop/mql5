//+------------------------------------------------------------------+
//|                                MovingAverage_Ribbon_MTF_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.10" // Simplified to use a single, central timeframe
#property description "A 4-line MA Ribbon calculated on a single, user-selected timeframe."

#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

//--- Plot Properties (Unchanged) ---
#property indicator_label1  "MA 1"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label2  "MA 2"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSkyBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
#property indicator_label3  "MA 3"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1
#property indicator_label4  "MA 4"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrRoyalBlue
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

#include <MyIncludes\MovingAverage_Ribbon_MTF_Calculator.mqh>

//--- Input Parameters (SIMPLIFIED) ---
input group "Timeframe & Price Source"
input ENUM_TIMEFRAMES           InpUpperTimeframe = PERIOD_H1;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;

input group "MA 1 Settings"
input int             InpPeriod1    = 8;
input ENUM_MA_TYPE    InpMAType1    = EMA;

input group "MA 2 Settings"
input int             InpPeriod2    = 13;
input ENUM_MA_TYPE    InpMAType2    = EMA;

input group "MA 3 Settings"
input int             InpPeriod3    = 21;
input ENUM_MA_TYPE    InpMAType3    = EMA;

input group "MA 4 Settings"
input int             InpPeriod4    = 34;
input ENUM_MA_TYPE    InpMAType4    = EMA;

//--- Indicator Buffers ---
double    BufferMA1[], BufferMA2[], BufferMA3[], BufferMA4[];

//--- Global calculator object ---
CMovingAverageRibbonMTFCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMA1, INDICATOR_DATA);
   SetIndexBuffer(1, BufferMA2, INDICATOR_DATA);
   SetIndexBuffer(2, BufferMA3, INDICATOR_DATA);
   SetIndexBuffer(3, BufferMA4, INDICATOR_DATA);
   ArraySetAsSeries(BufferMA1, false);
   ArraySetAsSeries(BufferMA2, false);
   ArraySetAsSeries(BufferMA3, false);
   ArraySetAsSeries(BufferMA4, false);

   g_calculator = new CMovingAverageRibbonMTFCalculator();

   bool is_ha = (InpSourcePrice <= PRICE_HA_CLOSE);

//--- UPDATED: Pass the single central timeframe to all four slots ---
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpUpperTimeframe, InpPeriod1, InpMAType1,
                         InpUpperTimeframe, InpPeriod2, InpMAType2,
                         InpUpperTimeframe, InpPeriod3, InpMAType3,
                         InpUpperTimeframe, InpPeriod4, InpMAType4,
                         is_ha))
     {
      Print("Failed to initialize Moving Average Ribbon MTF Calculator.");
      return(INIT_FAILED);
     }

   ENUM_TIMEFRAMES calc_tf = (InpUpperTimeframe == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpUpperTimeframe;
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MA Ribbon MTF%s(%s)", (is_ha ? " HA" : ""), EnumToString(calc_tf)));

   PlotIndexSetString(0, PLOT_LABEL, StringFormat("%s(%d)", EnumToString(InpMAType1), InpPeriod1));
   PlotIndexSetString(1, PLOT_LABEL, StringFormat("%s(%d)", EnumToString(InpMAType2), InpPeriod2));
   PlotIndexSetString(2, PLOT_LABEL, StringFormat("%s(%d)", EnumToString(InpMAType3), InpPeriod3));
   PlotIndexSetString(3, PLOT_LABEL, StringFormat("%s(%d)", EnumToString(InpMAType4), InpPeriod4));

   int max_period = MathMax(InpPeriod1, MathMax(InpPeriod2, MathMax(InpPeriod3, InpPeriod4)));
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, max_period);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, max_period);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, max_period);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, max_period);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;
   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;
   g_calculator.Calculate(rates_total, time, price_type, open, high, low, close, BufferMA1, BufferMA2, BufferMA3, BufferMA4);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
