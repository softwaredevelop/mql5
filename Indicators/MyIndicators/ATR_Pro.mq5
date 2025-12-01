//+------------------------------------------------------------------+
//|                                                       ATR_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.20" // Optimized for incremental calculation
#property description "Professional Average True Range (ATR) with selectable display mode."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

#property indicator_label1  "ATR"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\ATR_Calculator.mqh>

//--- Input Parameters ---
input int                  InpAtrPeriod    = 14;              // ATR Period
input ENUM_ATR_DISPLAY_MODE InpDisplayMode  = ATR_POINTS;      // Display Mode (Points or Percent)
input ENUM_CANDLE_SOURCE   InpCandleSource = CANDLE_STANDARD; // Candle source

//--- Indicator Buffers ---
double    BufferATR[];

//--- Global calculator object ---
CATRCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferATR, INDICATOR_DATA);
   ArraySetAsSeries(BufferATR, false);

   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CATRCalculator_HA();
         break;
      default:
         g_calculator = new CATRCalculator();
         break;
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpAtrPeriod, InpDisplayMode))
     {
      Print("Failed to create or initialize ATR Calculator object.");
      return(INIT_FAILED);
     }

   if(InpDisplayMode == ATR_PERCENT)
     {
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ATR%% %s(%d)", (InpCandleSource == CANDLE_HEIKIN_ASHI ? "HA " : ""), InpAtrPeriod));
      //--- UPDATED: Increased precision for Percent mode
      IndicatorSetInteger(INDICATOR_DIGITS, 4);
     }
   else
     {
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ATR %s(%d)", (InpCandleSource == CANDLE_HEIKIN_ASHI ? "HA " : ""), InpAtrPeriod));
      IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_calculator.GetPeriod());
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Free the calculator object to prevent memory leaks
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation function.                           |
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

//--- Delegate calculation with prev_calculated optimization
   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferATR);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
