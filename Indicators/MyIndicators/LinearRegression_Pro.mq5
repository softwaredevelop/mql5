//+------------------------------------------------------------------+
//|                                         LinearRegression_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.10" // Optimized for incremental calculation
#property description "Professional, manually calculated Linear Regression Channel with"
#property description "selectable price source (Standard and Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 3 // Upper, Lower, Middle
#property indicator_plots   3

//--- Plot 1: Upper Channel
#property indicator_label1  "Upper"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_DOT

//--- Plot 2: Lower Channel
#property indicator_label2  "Lower"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_DOT

//--- Plot 3: Regression Line (Middle)
#property indicator_label3  "Regression"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_style3  STYLE_SOLID

//--- Include the calculator engine ---
#include <MyIncludes\LinearRegression_Calculator.mqh>

//--- Input Parameters ---
input int                       InpRegressionPeriod = 100;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice      = PRICE_CLOSE_STD;
input ENUM_CHANNEL_MODE         InpChannelMode      = DEVIATION_STANDARD;
input double                    InpDeviations       = 2.0;

//--- Indicator Buffers ---
double    BufferUpper[];
double    BufferLower[];
double    BufferMiddle[];

//--- Global Variables ---
datetime                  g_last_update_time;
CLinearRegressionCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_last_update_time = 0;

   SetIndexBuffer(0, BufferUpper,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferLower,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferMiddle, INDICATOR_DATA);
   ArraySetAsSeries(BufferUpper,  false);
   ArraySetAsSeries(BufferLower,  false);
   ArraySetAsSeries(BufferMiddle, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CLinearRegressionCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("LinReg HA(%d)", InpRegressionPeriod));
     }
   else
     {
      g_calculator = new CLinearRegressionCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("LinReg(%d)", InpRegressionPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpRegressionPeriod, InpChannelMode, InpDeviations))
     {
      Print("Failed to initialize Linear Regression Calculator.");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
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
//| Linear Regression Channel calculation function.                  |
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

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Delegate calculation with prev_calculated optimization
   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, price_type, BufferMiddle, BufferUpper, BufferLower);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
