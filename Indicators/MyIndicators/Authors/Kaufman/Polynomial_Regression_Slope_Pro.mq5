//+------------------------------------------------------------------+
//|                             Polynomial_Regression_Slope_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Calculates the slope (1st derivative) of a moving Polynomial Regression."
#property description "Functions as a smooth, zero-lag momentum oscillator."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

#property indicator_label1  "Slope"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\Polynomial_Regression_Slope_Calculator.mqh>

//--- Input Parameters ---
input int                       InpPeriod      = 50;    // Regression Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferSlope[];

//--- Global calculator object ---
CPolynomialRegressionSlopeCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferSlope, INDICATOR_DATA);
   ArraySetAsSeries(BufferSlope, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CPolynomialRegressionSlopeCalculator_HA();
   else
      g_calculator = new CPolynomialRegressionSlopeCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod))
     {
      Print("Failed to initialize Polynomial Regression Slope Calculator.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("PolyReg Slope%s(%d)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpPeriod));
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, 4);

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
   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferSlope);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
