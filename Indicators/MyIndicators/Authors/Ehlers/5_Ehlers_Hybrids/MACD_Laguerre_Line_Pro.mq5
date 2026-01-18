//+------------------------------------------------------------------+
//|                                     MACD_Laguerre_Line_Pro.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Updated to use unified calculator
#property description "MACD Line calculated from two Laguerre filters."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

#property indicator_label1  "MACD Line"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\MACD_Laguerre_Calculator.mqh>

//--- Input Parameters
input double                    InpGamma1       = 0.2; // Fast Laguerre Gamma
input double                    InpGamma2       = 0.8; // Slow Laguerre Gamma
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers
double    BufferMACDLine[];

//--- Global calculator object
CMACDLaguerreCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMACDLine, INDICATOR_DATA);
   ArraySetAsSeries(BufferMACDLine, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMACDLaguerreCalculator_HA();
   else
      g_calculator = new CMACDLaguerreCalculator();

// Initialize with dummy signal parameters (not used for Line Only)
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpGamma1, InpGamma2, 0.5, 9, SMOOTH_SMA))
     {
      Print("Failed to create or initialize MACD Laguerre Calculator.");
      return(INIT_FAILED);
     }

   string short_name = StringFormat("MACD Laguerre Line%s(%.2f,%.2f)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpGamma1, InpGamma2);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

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

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

// Use the MACD Line only wrapper
   g_calculator.CalculateMACDLineOnly(rates_total, prev_calculated, open, high, low, close, price_type, BufferMACDLine);

   return(rates_total);
  }
//+------------------------------------------------------------------+
