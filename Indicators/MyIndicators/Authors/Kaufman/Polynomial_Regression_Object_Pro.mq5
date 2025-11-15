//+------------------------------------------------------------------+
//|                             Polynomial_Regression_Object_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Draws a single, moving Curvilinear Regression Channel using objects."

#property indicator_chart_window
#property indicator_buffers 0 // No buffers are used for plotting
#property indicator_plots   0

#include <MyIncludes\Polynomial_Regression_Object_Calculator.mqh>

//--- Input Parameters ---
input int                       InpPeriod      = 50;    // Regression Period
input double                    InpDeviation   = 2.0;   // Deviation for bands
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Global variables ---
CPolynomialRegressionObjectCalculator *g_calculator;
string                               g_unique_prefix;

//+------------------------------------------------------------------+
int OnInit()
  {
//--- Create a unique prefix for our objects
   g_unique_prefix = StringFormat("PolyRegObj_%d_%d", ChartID(), GetTickCount());

//--- Clean up any leftover objects from a previous run
   ObjectsDeleteAll(0, g_unique_prefix);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CPolynomialRegressionObjectCalculator_HA();
   else
      g_calculator = new CPolynomialRegressionObjectCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpDeviation, g_unique_prefix))
     {
      Print("Failed to initialize Polynomial Regression Object Calculator.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("PolyReg Obj%s(%d,%.1f)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpPeriod, InpDeviation));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Clean up our graphical objects
   ObjectsDeleteAll(0, g_unique_prefix);

   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;
   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- The calculator now needs the time array for object placement
   g_calculator.Calculate(rates_total, time, price_type, open, high, low, close);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
