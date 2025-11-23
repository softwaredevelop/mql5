//+------------------------------------------------------------------+
//|                                             CenteredMA_Pro.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Centered Moving Average (CMA) for cycle analysis, based on J.M. Hurst's concepts."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "CMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumPurple
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\CenteredMA_Calculator.mqh>

//--- Input Parameters ---
input int                       InpPeriod      = 20;
input ENUM_MA_TYPE              InpMAType      = SMA;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferCMA[];

//--- Global calculator object ---
CCenteredMACalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferCMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferCMA, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CCenteredMACalculator_HA();
   else
      g_calculator = new CCenteredMACalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpMAType))
     {
      Print("Failed to initialize Centered MA Calculator.");
      return(INIT_FAILED);
     }

   string ma_name = EnumToString(InpMAType);
   StringToUpper(ma_name);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CMA %s%s(%d)", ma_name, (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpPeriod));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod / 2);
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
   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferCMA);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
