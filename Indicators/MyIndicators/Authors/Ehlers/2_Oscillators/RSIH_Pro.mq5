//+------------------------------------------------------------------+
//|                                                     RSIH_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Added optional Noise Elimination Technology (NET)
#property description "John Ehlers' Improved RSI with Hann Windowing (RSIH) and optional NET filter."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Base RSIH
#property indicator_label1  "RSIH"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGray
#property indicator_style1  STYLE_DOT
#property indicator_width1  1

//--- Plot 2: NET-filtered RSIH
#property indicator_label2  "NET(RSIH)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_minimum -1.1
#property indicator_maximum 1.1
#property indicator_level1 0.5
#property indicator_level2 0.0
#property indicator_level3 -0.5
#property indicator_levelcolor clrGray
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\RSIH_Calculator.mqh>

//--- Input Parameters ---
input int                       InpPeriodRSI    = 14;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;
input group "Noise Elimination Technology (NET)"
input bool                      InpApplyNET     = true;
input int                       InpPeriodNET    = 14;

//--- Indicator Buffers ---
double    BufferRSIH[];
double    BufferNET[];

//--- Global calculator object ---
CRSIHCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferRSIH, INDICATOR_DATA);
   SetIndexBuffer(1, BufferNET,  INDICATOR_DATA);
   ArraySetAsSeries(BufferRSIH, false);
   ArraySetAsSeries(BufferNET,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CRSIHCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RSIH HA(%d,%d)", InpPeriodRSI, InpPeriodNET));
     }
   else
     {
      g_calculator = new CRSIHCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RSIH(%d,%d)", InpPeriodRSI, InpPeriodNET));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriodRSI, InpPeriodNET))
     {
      Print("Failed to create or initialize RSIH Calculator object.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriodRSI + 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpPeriodRSI + InpPeriodNET + 1);
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

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferRSIH, BufferNET);

// Hide buffers if not enabled by the user
   if(!InpApplyNET)
     {
      for(int i=0; i<rates_total; i++)
        {
         BufferNET[i] = EMPTY_VALUE;
         // If NET is off, make the base RSIH the main line
         PlotIndexSetInteger(0, PLOT_LINE_STYLE, STYLE_SOLID);
         PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrDodgerBlue);
        }
     }
   else
     {
      // Restore default styles if NET is on
      PlotIndexSetInteger(0, PLOT_LINE_STYLE, STYLE_DOT);
      PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrGray);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
