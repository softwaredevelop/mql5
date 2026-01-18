//+------------------------------------------------------------------+
//|                                                     RSIH_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.10" // Fixed visual consistency
#property description "John Ehlers' Improved RSI with Hann Windowing (RSIH) and optional NET filter."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Base RSIH
#property indicator_label1  "RSIH"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue      // Fixed color
#property indicator_style1  STYLE_SOLID    // Fixed style
#property indicator_width1  1

//--- Plot 2: NET-filtered RSIH
#property indicator_label2  "NET(RSIH)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGray
#property indicator_style2  STYLE_DOT
#property indicator_width2  1            // Thicker line for emphasis

#property indicator_minimum -1
#property indicator_maximum 1
#property indicator_level1 0.75
#property indicator_level2 0.5
#property indicator_level3 0.0
#property indicator_level4 -0.5
#property indicator_level5 -0.75
//#property indicator_levelcolor clrGray
//#property indicator_levelstyle STYLE_DOT

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
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferRSIH, INDICATOR_DATA);
   SetIndexBuffer(1, BufferNET,  INDICATOR_DATA);
   ArraySetAsSeries(BufferRSIH, false);
   ArraySetAsSeries(BufferNET,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CRSIHCalculator_HA();
   else
      g_calculator = new CRSIHCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriodRSI, InpPeriodNET))
     {
      Print("Failed to create or initialize RSIH Calculator object.");
      return(INIT_FAILED);
     }

   string netStr = InpApplyNET ? StringFormat(", NET %d", InpPeriodNET) : "";
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RSIH%s(%d%s)", type, InpPeriodRSI, netStr));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriodRSI + 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpPeriodRSI + InpPeriodNET + 1);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

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
   if(rates_total < InpPeriodRSI + 1)
      return(0);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          BufferRSIH, BufferNET);

// Visual Logic: Hide NET buffer if not enabled
   if(!InpApplyNET)
     {
      int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      for(int i = start; i < rates_total; i++)
         BufferNET[i] = EMPTY_VALUE;
     }
// Removed dynamic style changing logic for RSIH

   return(rates_total);
  }
//+------------------------------------------------------------------+
