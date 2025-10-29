//+------------------------------------------------------------------+
//|                                                      DMH_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "John Ehlers' DMH (Directional Movement with Hann Windowing)."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "DMH"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_level1 0.0
#property indicator_levelstyle STYLE_SOLID
#property indicator_levelcolor clrGray

#include <MyIncludes\DMH_Calculator.mqh>

enum ENUM_CANDLE_SOURCE { SOURCE_STANDARD, SOURCE_HEIKIN_ASHI };

//--- Input Parameters ---
input int               InpPeriod = 14;
input ENUM_CANDLE_SOURCE InpSource = SOURCE_STANDARD;

//--- Indicator Buffers ---
double    BufferDMH[];

//--- Global calculator object ---
CDMHCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferDMH,  INDICATOR_DATA);
   ArraySetAsSeries(BufferDMH,  false);

   if(InpSource == SOURCE_HEIKIN_ASHI)
     {
      g_calculator = new CDMHCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("DMH HA(%d)", InpPeriod));
     }
   else
     {
      g_calculator = new CDMHCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("DMH(%d)", InpPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod))
     {
      Print("Failed to initialize DMH Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod * 2);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

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
   g_calculator.Calculate(rates_total, open, high, low, close, BufferDMH);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
