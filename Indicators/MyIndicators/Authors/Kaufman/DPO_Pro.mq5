//+------------------------------------------------------------------+
//|                                                      DPO_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Optimized for incremental calculation
#property description "Detrended Price Oscillator (DPO). Shows cycles by removing the trend."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "DPO"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\DPO_Calculator.mqh>

//--- Input Parameters ---
input int                       InpPeriod      = 21;
input ENUM_MA_TYPE              InpMAType      = SMA;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferDPO[];

//--- Global calculator object ---
CDPOCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferDPO, INDICATOR_DATA);
   ArraySetAsSeries(BufferDPO, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CDPOCalculator_HA();
   else
      g_calculator = new CDPOCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpMAType))
     {
      Print("Failed to initialize DPO Calculator.");
      return(INIT_FAILED);
     }

   string ma_name = EnumToString(InpMAType);
   StringToUpper(ma_name);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("DPO %s%s(%d)", ma_name, (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpPeriod));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;
   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferDPO);

   return(rates_total);
  }
//+------------------------------------------------------------------+
