//+------------------------------------------------------------------+
//|                                    Ehlers_Smoother_Lab_Pro.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "A laboratory for comparing two different Ehlers (or classic) smoothing filters."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_label1  "Filter 1"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "Filter 2"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\Ehlers_Smoother_Lab_Calculator.mqh>

//--- Input Parameters ---
input group "Filter 1 Settings"
input ENUM_SMOOTHER_TYPE        InpFilter1_Type   = BUTTERWORTH_2P;
input int                       InpFilter1_Period = 20;
input ENUM_APPLIED_PRICE_HA_ALL InpFilter1_Source = PRICE_CLOSE_STD;

input group "Filter 2 Settings"
input ENUM_SMOOTHER_TYPE        InpFilter2_Type   = SUPERSMOOTHER;
input int                       InpFilter2_Period = 20;
input ENUM_APPLIED_PRICE_HA_ALL InpFilter2_Source = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferFilter1[];
double    BufferFilter2[];

//--- Global calculator objects ---
CSmootherLabCalculator *g_calc1;
CSmootherLabCalculator *g_calc2;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferFilter1, INDICATOR_DATA);
   SetIndexBuffer(1, BufferFilter2, INDICATOR_DATA);
   ArraySetAsSeries(BufferFilter1, false);
   ArraySetAsSeries(BufferFilter2, false);

// --- Initialize Filter 1 ---
   if(InpFilter1_Source <= PRICE_HA_CLOSE)
      g_calc1 = new CSmootherLabCalculator_HA();
   else
      g_calc1 = new CSmootherLabCalculator();
   if(CheckPointer(g_calc1) == POINTER_INVALID || !g_calc1.Init(InpFilter1_Type, InpFilter1_Period))
     {
      Print("Failed to initialize Filter 1.");
      return(INIT_FAILED);
     }

// --- Initialize Filter 2 ---
   if(InpFilter2_Source <= PRICE_HA_CLOSE)
      g_calc2 = new CSmootherLabCalculator_HA();
   else
      g_calc2 = new CSmootherLabCalculator();
   if(CheckPointer(g_calc2) == POINTER_INVALID || !g_calc2.Init(InpFilter2_Type, InpFilter2_Period))
     {
      Print("Failed to initialize Filter 2.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, "Ehlers Smoother Lab");
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, MathMax(InpFilter1_Period, 10));
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, MathMax(InpFilter2_Period, 10));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calc1) != POINTER_INVALID)
      delete g_calc1;
   if(CheckPointer(g_calc2) != POINTER_INVALID)
      delete g_calc2;
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calc1) == POINTER_INVALID || CheckPointer(g_calc2) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE type1, type2;
   if(InpFilter1_Source <= PRICE_HA_CLOSE)
      type1 = (ENUM_APPLIED_PRICE)(-(int)InpFilter1_Source);
   else
      type1 = (ENUM_APPLIED_PRICE)InpFilter1_Source;
   if(InpFilter2_Source <= PRICE_HA_CLOSE)
      type2 = (ENUM_APPLIED_PRICE)(-(int)InpFilter2_Source);
   else
      type2 = (ENUM_APPLIED_PRICE)InpFilter2_Source;

   g_calc1.Calculate(rates_total, type1, open, high, low, close, BufferFilter1);
   g_calc2.Calculate(rates_total, type2, open, high, low, close, BufferFilter2);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
