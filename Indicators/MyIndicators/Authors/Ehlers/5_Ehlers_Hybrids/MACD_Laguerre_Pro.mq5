//+------------------------------------------------------------------+
//|                                           MACD_Laguerre_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.10" // Added selectable signal line type
#property description "Full MACD with Laguerre base lines and a selectable signal line."

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
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\MACD_Laguerre_Calculator.mqh>

//--- Input Parameters ---
input group "Laguerre MACD Settings"
input double InpGamma1 = 0.2; // Fast Laguerre Gamma (smaller value)
input double InpGamma2 = 0.8; // Slow Laguerre Gamma (larger value)

input group "Signal Line Settings"
input ENUM_SMOOTHING_METHOD_LAGUERRE InpSignalMAType = SMOOTH_Laguerre; // Default to Laguerre
input int                            InpSignalPeriod = 9;             // Period for standard MAs
input double                         InpSignalGamma  = 0.5;           // Gamma for Laguerre signal line

input group "Price Source"
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferHistogram[], BufferMACDLine[], BufferSignalLine[];

//--- Global calculator object ---
CMACDLaguerreCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferHistogram,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferMACDLine,   INDICATOR_DATA);
   SetIndexBuffer(2, BufferSignalLine, INDICATOR_DATA);
   ArraySetAsSeries(BufferHistogram, false);
   ArraySetAsSeries(BufferMACDLine, false);
   ArraySetAsSeries(BufferSignalLine, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMACDLaguerreCalculator_HA();
   else
      g_calculator = new CMACDLaguerreCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpGamma1, InpGamma2, InpSignalGamma, InpSignalPeriod, InpSignalMAType))
     {
      Print("Failed to create or initialize MACD Laguerre Calculator.");
      return(INIT_FAILED);
     }

   string short_name = StringFormat("MACD Laguerre%s", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""));
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2 + InpSignalPeriod);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 2);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, 2 + InpSignalPeriod);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;
   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;
   g_calculator.Calculate(rates_total, open, high, low, close, price_type, BufferMACDLine, BufferSignalLine, BufferHistogram);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
