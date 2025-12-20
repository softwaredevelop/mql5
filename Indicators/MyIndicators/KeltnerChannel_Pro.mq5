//+------------------------------------------------------------------+
//|                                           KeltnerChannel_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.00" // Refactored to use MovingAverage_Engine
#property description "Professional Keltner Channels with separate source selection"
#property description "for the Middle Line (MA) and the ATR calculation."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

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

//--- Plot 3: Middle Band (Basis)
#property indicator_label3  "Basis"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOliveDrab
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Include the calculator engine ---
#include <MyIncludes\KeltnerChannel_Calculator.mqh>

//--- Input Parameters ---
input group                     "Middle Line (MA) Settings"
input int                       InpMaPeriod     = 20;
// UPDATED: Use ENUM_MA_TYPE
input ENUM_MA_TYPE              InpMaMethod     = EMA;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_TYPICAL_STD;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group                     "Channel (ATR) Settings"
input int                       InpAtrPeriod    = 10;
input double                    InpMultiplier   = 2.0;
input ENUM_ATR_SOURCE           InpAtrSource    = ATR_SOURCE_STANDARD;

//--- Indicator Buffers ---
double    BufferUpper[];
double    BufferLower[];
double    BufferMiddle[];

//--- Global calculator object ---
CKeltnerChannelCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferUpper,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferLower,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferMiddle, INDICATOR_DATA);
   ArraySetAsSeries(BufferUpper,  false);
   ArraySetAsSeries(BufferLower,  false);
   ArraySetAsSeries(BufferMiddle, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CKeltnerChannelCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("KC HA(%d,%d,%s)", InpMaPeriod, InpAtrPeriod, EnumToString(InpMaMethod)));
     }
   else
     {
      g_calculator = new CKeltnerChannelCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("KC(%d,%d,%s)", InpMaPeriod, InpAtrPeriod, EnumToString(InpMaMethod)));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpMaPeriod, InpMaMethod, InpAtrPeriod, InpMultiplier, InpAtrSource))
     {
      Print("Failed to create or initialize Keltner Channel Calculator object.");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   int draw_begin = MathMax(InpMaPeriod, InpAtrPeriod);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, InpMaPeriod - 1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation function                            |
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

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, price_type, BufferMiddle, BufferUpper, BufferLower);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
