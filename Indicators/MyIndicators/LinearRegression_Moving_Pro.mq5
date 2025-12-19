//+------------------------------------------------------------------+
//|                                  LinearRegression_Moving_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.00" // True Moving Linear Regression
#property description "Professional Moving Linear Regression (Curve)."
#property description "Plots the end-point of the regression line for every bar."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 3 // Upper, Lower, Middle
#property indicator_plots   3

//--- Plot 1: Upper Channel
#property indicator_label1  "Upper"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_DOT
#property indicator_width1  1

//--- Plot 2: Lower Channel
#property indicator_label2  "Lower"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Plot 3: Regression Line (Middle)
#property indicator_label3  "Regression"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

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
CLinearRegressionCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferUpper,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferLower,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferMiddle, INDICATOR_DATA);

// Standard indexing for buffers
   ArraySetAsSeries(BufferUpper,  false);
   ArraySetAsSeries(BufferLower,  false);
   ArraySetAsSeries(BufferMiddle, false);

// Instantiate Calculator based on Price Source
   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CLinearRegressionCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("LinReg Moving HA(%d)", InpRegressionPeriod));
     }
   else
     {
      g_calculator = new CLinearRegressionCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("LinReg Moving(%d)", InpRegressionPeriod));
     }

// Initialize Calculator
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpRegressionPeriod, InpChannelMode, InpDeviations))
     {
      Print("Failed to initialize Linear Regression Calculator.");
      return(INIT_FAILED);
     }

// Set Draw Begin: Hide the initial period where regression cannot be calculated
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpRegressionPeriod);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpRegressionPeriod);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, InpRegressionPeriod);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);

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

//--- Delegate calculation with prev_calculated optimization
//--- Using CalculateMoving for the continuous curve
   g_calculator.CalculateMoving(rates_total, prev_calculated, open, high, low, close, price_type, BufferMiddle, BufferUpper, BufferLower);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
