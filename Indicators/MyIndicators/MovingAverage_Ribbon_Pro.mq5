//+------------------------------------------------------------------+
//|                                     MovingAverage_Ribbon_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.10" // Optimized for incremental calculation
#property description "A 4-line Moving Average Ribbon with fully customizable periods and types."

#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

//--- Plot Properties
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

#include <MyIncludes\MovingAverage_Ribbon_Calculator.mqh>

//--- Input Parameters ---
input group "MA 1 Settings"
input int        InpPeriod1 = 8;
input ENUM_MA_TYPE InpMAType1 = EMA;

input group "MA 2 Settings"
input int        InpPeriod2 = 13;
input ENUM_MA_TYPE InpMAType2 = EMA;

input group "MA 3 Settings"
input int        InpPeriod3 = 21;
input ENUM_MA_TYPE InpMAType3 = EMA;

input group "MA 4 Settings"
input int        InpPeriod4 = 34;
input ENUM_MA_TYPE InpMAType4 = EMA;

input group "Price Source"
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferMA1[], BufferMA2[], BufferMA3[], BufferMA4[];

//--- Global calculator object ---
CMovingAverageRibbonCalculator *g_calculator;

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

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMovingAverageRibbonCalculator_HA();
   else
      g_calculator = new CMovingAverageRibbonCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriod1, InpMAType1, InpPeriod2, InpMAType2, InpPeriod3, InpMAType3, InpPeriod4, InpMAType4))
     {
      Print("Failed to initialize Moving Average Ribbon Calculator.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MA Ribbon%s", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : "")));

   PlotIndexSetString(0, PLOT_LABEL, StringFormat("%s(%d)", EnumToString(InpMAType1), InpPeriod1));
   PlotIndexSetString(1, PLOT_LABEL, StringFormat("%s(%d)", EnumToString(InpMAType2), InpPeriod2));
   PlotIndexSetString(2, PLOT_LABEL, StringFormat("%s(%d)", EnumToString(InpMAType3), InpPeriod3));
   PlotIndexSetString(3, PLOT_LABEL, StringFormat("%s(%d)", EnumToString(InpMAType4), InpPeriod4));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod1 - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpPeriod2 - 1);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, InpPeriod3 - 1);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, InpPeriod4 - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

//+------------------------------------------------------------------+
//| Custom indicator calculation function.                           |
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

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Delegate calculation with prev_calculated optimization
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          BufferMA1, BufferMA2, BufferMA3, BufferMA4);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
