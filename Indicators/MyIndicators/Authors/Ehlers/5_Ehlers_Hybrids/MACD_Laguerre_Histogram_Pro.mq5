//+------------------------------------------------------------------+
//|                               MACD_Laguerre_Histogram_Pro.mq5    |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.20" // Optimized for incremental calculation
#property description "Histogram for the Laguerre MACD with a selectable signal line."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

#property indicator_label1  "Histogram"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\MACD_Laguerre_Histogram_Calculator.mqh>

//--- Input Parameters ---
input group "Laguerre MACD Settings"
input double InpGamma1 = 0.2; // Fast Laguerre Gamma (smaller value)
input double InpGamma2 = 0.8; // Slow Laguerre Gamma (larger value)

input group "Signal Line Settings"
input ENUM_SMOOTHING_METHOD_LAGUERRE InpSignalMAType = SMOOTH_Laguerre;
input int                            InpSignalPeriod = 9;
input double                         InpSignalGamma  = 0.5;

input group "Price Source"
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferHistogram[];

//--- Global calculator object ---
CMACDLaguerreHistogramCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferHistogram, INDICATOR_DATA);
   ArraySetAsSeries(BufferHistogram, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMACDLaguerreHistogramCalculator_HA();
   else
      g_calculator = new CMACDLaguerreHistogramCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpGamma1, InpGamma2, InpSignalGamma, InpSignalPeriod, InpSignalMAType))
     {
      Print("Failed to create or initialize MACD Laguerre Histogram Calculator.");
      return(INIT_FAILED);
     }

   string ma_name = EnumToString(InpSignalMAType);
   StringReplace(ma_name, "SMOOTH_", "");
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Laguerre Histo(%s)", ma_name));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2 + InpSignalPeriod);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

//+------------------------------------------------------------------+
//| Custom indicator calculation function                            |
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
   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, price_type, BufferHistogram);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
