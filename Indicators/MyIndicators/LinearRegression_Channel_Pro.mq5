//+------------------------------------------------------------------+
//|                                 LinearRegression_Channel_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.10" // Fixed initialization bug (Vertical Lines)
#property description "Professional Linear Regression Channel (Straight Segment)"
#property description "Draws the regression channel for the most recent N bars."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 3
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

#include <MyIncludes\LinearRegression_Calculator.mqh>

//--- Input Parameters ---
input int                       InpRegressionPeriod = 100;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice      = PRICE_CLOSE_STD;
input ENUM_CHANNEL_MODE         InpChannelMode      = DEVIATION_STANDARD;
input double                    InpDeviations       = 2.0;

//--- Buffers
double    BufferUpper[];
double    BufferLower[];
double    BufferMiddle[];

CLinearRegressionCalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferUpper,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferLower,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferMiddle, INDICATOR_DATA);

   ArraySetAsSeries(BufferUpper,  false);
   ArraySetAsSeries(BufferLower,  false);
   ArraySetAsSeries(BufferMiddle, false);

// Initialize with EMPTY_VALUE to hide the line outside the channel
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CLinearRegressionCalculator_HA();
   else
      g_calculator = new CLinearRegressionCalculator();

   if(!g_calculator.Init(InpRegressionPeriod, InpChannelMode, InpDeviations))
      return(INIT_FAILED);

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("LinReg Channel(%d)", InpRegressionPeriod));
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
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// CRITICAL FIX: Initialize buffers on full recalculation (e.g. timeframe switch)
// This prevents "ghost" 0.0 values which cause vertical lines.
   if(prev_calculated == 0)
     {
      ArrayInitialize(BufferUpper, EMPTY_VALUE);
      ArrayInitialize(BufferLower, EMPTY_VALUE);
      ArrayInitialize(BufferMiddle, EMPTY_VALUE);
     }

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

// Clear the buffer index just before the channel starts to create the visual "cut"
// This handles the movement of the channel forward in time.
   int start_pos = rates_total - InpRegressionPeriod;
   if(start_pos > 0)
     {
      BufferUpper[start_pos-1] = EMPTY_VALUE;
      BufferLower[start_pos-1] = EMPTY_VALUE;
      BufferMiddle[start_pos-1] = EMPTY_VALUE;
     }

   g_calculator.CalculateStaticChannel(rates_total, open, high, low, close, price_type, BufferMiddle, BufferUpper, BufferLower);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
