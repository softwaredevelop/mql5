//+------------------------------------------------------------------+
//|                                     MACD_SuperSmoother_Pro.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.00" // Updated to support extended Signal types
#property description "MACD with SuperSmoother base lines and a selectable signal line."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3

#property indicator_label1  "Histogram"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1
#property indicator_label2  "MACD"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
#property indicator_label3  "Signal"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#include <MyIncludes\MACD_SuperSmoother_Calculator.mqh>

//--- Input Parameters ---
input group "MACD Settings"
input int                       InpFastPeriod   = 12;
input int                       InpSlowPeriod   = 26;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

input group "Signal Line Settings"
input int                       InpSignalPeriod = 9;
input ENUM_SMOOTHING_METHOD_SS  InpSignalMAType = SMOOTH_SuperSmoother; // Updated Enum

//--- Indicator Buffers ---
double    BufferMACD_Histogram[], BufferMACDLine[], BufferSignalLine[];

//--- Global calculator object ---
CMACDSuperSmootherCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMACD_Histogram, INDICATOR_DATA);
   SetIndexBuffer(1, BufferMACDLine,       INDICATOR_DATA);
   SetIndexBuffer(2, BufferSignalLine,     INDICATOR_DATA);
   ArraySetAsSeries(BufferMACD_Histogram, false);
   ArraySetAsSeries(BufferMACDLine,       false);
   ArraySetAsSeries(BufferSignalLine,     false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMACDSuperSmootherCalculator_HA();
   else
      g_calculator = new CMACDSuperSmootherCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpFastPeriod, InpSlowPeriod, InpSignalPeriod, InpSignalMAType))
     {
      Print("Failed to create or initialize MACD SuperSmoother Calculator.");
      return(INIT_FAILED);
     }

   string ma_name = EnumToString(InpSignalMAType);
   StringReplace(ma_name, "SMOOTH_", "");
   string short_name = StringFormat("MACD SS%s(%d,%d,%s %d)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpFastPeriod, InpSlowPeriod, ma_name, InpSignalPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

   int draw_begin = InpSlowPeriod + InpSignalPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpSlowPeriod);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

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

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, price_type,
                          BufferMACDLine, BufferSignalLine, BufferMACD_Histogram);

   return(rates_total);
  }
//+------------------------------------------------------------------+
