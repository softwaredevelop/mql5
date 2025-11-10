//+------------------------------------------------------------------+
//|                                           MovingAverage_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.02" // Corrected function name to StringToUpper
#property description "Universal Moving Average (SMA, EMA, SMMA, LWMA) with Standard/Heikin Ashi source."
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "MA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Input Parameters ---
input int                       InpPeriod      = 20;
input ENUM_MA_TYPE              InpMAType      = SMA; // User can select the MA type
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferMA[];

//--- Global calculator object ---
CMovingAverageCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferMA, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMovingAverageCalculator_HA();
   else
      g_calculator = new CMovingAverageCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpMAType))
     {
      Print("Failed to initialize Moving Average Calculator.");
      return(INIT_FAILED);
     }

//--- Dynamically set the indicator name (CORRECTED LOGIC) ---
   string ma_name = EnumToString(InpMAType);
   StringToUpper(ma_name); // CORRECTED function name

   string short_name = StringFormat("%s%s(%d)", ma_name, (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpPeriod);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, short_name);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod - 1);
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
   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferMA);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
