//+------------------------------------------------------------------+
//|                                          Bollinger_Bands_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.00" // Refactored to use MovingAverage_Engine
#property description "Professional Bollinger Bands with extended MA types"
#property description "(SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA) and Heikin Ashi support."

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

#include <MyIncludes\Bollinger_Bands_Calculator.mqh>

//--- Plot 1: Upper Band
#property indicator_label1  "Upper Band"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrOliveDrab
#property indicator_style1  STYLE_DOT
#property indicator_width1  1

//--- Plot 2: Lower Band
#property indicator_label2  "Lower Band"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOliveDrab
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Plot 3: Center Line (MA)
#property indicator_label3  "Centerline"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOliveDrab
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Input Parameters ---
input int                       InpPeriod      = 20;
input double                    InpDeviation   = 2.0;
input ENUM_MA_TYPE              InpMAType      = SMA; // Updated to support all engine types
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferUpperBand[], BufferLowerBand[], BufferCenterLine[];

//--- Global calculator object ---
CBollingerBandsCalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferUpperBand,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferLowerBand,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferCenterLine, INDICATOR_DATA);

   ArraySetAsSeries(BufferUpperBand,  false);
   ArraySetAsSeries(BufferLowerBand,  false);
   ArraySetAsSeries(BufferCenterLine, false);

//--- Factory Logic
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CBollingerBandsCalculator_HA();
   else
      g_calculator = new CBollingerBandsCalculator();

//--- Initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriod, InpDeviation, InpMAType))
     {
      Print("Failed to initialize Bollinger Bands Calculator.");
      return(INIT_FAILED);
     }

//--- Shortname
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("BB Pro%s(%d, %.2f, %s)", type, InpPeriod, InpDeviation, EnumToString(InpMAType)));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpPeriod - 1);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, InpPeriod - 1);

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
   if(rates_total < InpPeriod)
      return(0);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          BufferCenterLine, BufferUpperBand, BufferLowerBand);

   return(rates_total);
  }
//+------------------------------------------------------------------+
