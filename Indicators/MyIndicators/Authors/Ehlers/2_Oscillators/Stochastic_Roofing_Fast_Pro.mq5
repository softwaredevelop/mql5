//+------------------------------------------------------------------+
//|                                 Stochastic_Roofing_Fast_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Fast Stochastic pre-filtered with John Ehlers' Roofing Filter."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_label1  "%K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_label2  "%D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_DOT
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 20.0
#property indicator_level2 80.0

#include <MyIncludes\Stochastic_Roofing_Calculator.mqh>

//--- Input Parameters ---
input group "Roofing Filter Settings"
input int                       InpHighPassPeriod      = 48;
input int                       InpSuperSmootherPeriod = 10;
input group "Stochastic Settings"
input int                       InpKPeriod             = 20;
input int                       InpDPeriod             = 3;
// Note: Slowing is not used for Fast Stochastic
input group "Source Settings"
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice         = PRICE_CLOSE_STD;

//--- Buffers ---
double    BufferK[], BufferD[];
//--- Global object ---
CStochasticRoofingCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferK,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferD,  INDICATOR_DATA);
   ArraySetAsSeries(BufferK,  false);
   ArraySetAsSeries(BufferD,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CStochasticRoofingCalculator_HA();
   else
      g_calculator = new CStochasticRoofingCalculator();

// The 'slowing' parameter is passed as 1 but is not used in the FAST calculation path
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpHighPassPeriod, InpSuperSmootherPeriod, InpKPeriod, InpDPeriod, 1, STOCH_FAST))
     {
      Print("Failed to initialize Stochastic Roofing Calculator.");
      return(INIT_FAILED);
     }
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("StochRoof Fast(%d,%d)", InpHighPassPeriod, InpKPeriod));
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }
//+------------------------------------------------------------------+
//|                                                                  |
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
   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferK, BufferD);
   return(rates_total);
  }
//+------------------------------------------------------------------+
