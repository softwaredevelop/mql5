//+------------------------------------------------------------------+
//|                                            HighPass_2P_Pro.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "John Ehlers' 2-Pole High-Pass Filter for detrending."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "HP(2P)"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_level1 0.0
#property indicator_levelstyle STYLE_SOLID
#property indicator_levelcolor clrGray

#include <MyIncludes\HighPass_2P_Calculator.mqh>

//--- Input Parameters ---
input int                       InpPeriod       = 20;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferHP[];

//--- Global calculator object ---
CHighPass2P_Calculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferHP,  INDICATOR_DATA);
   ArraySetAsSeries(BufferHP,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CHighPass2P_Calculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HP-2P HA(%d)", InpPeriod));
     }
   else
     {
      g_calculator = new CHighPass2P_Calculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HP-2P(%d)", InpPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod))
     {
      Print("Failed to initialize 2-Pole High-Pass Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 3);
   IndicatorSetInteger(INDICATOR_DIGITS, 4);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferHP);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
