//+------------------------------------------------------------------+
//|                                  MovingAverage_Anchored_Pro.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Universal Anchored Moving Average with segmented gapped drawing
#property description "Universal Anchored Moving Average (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, VWMA)."
#property description "Resets its calculation baseline on specific calendar events to prevent connecting line drag."
#property indicator_chart_window
#property indicator_buffers 2 // Two buffers for gapped drawing
#property indicator_plots   2

//--- Plot 1: MA Line (Odd Periods)
#property indicator_label1  "MA Anchored"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: MA Line (Even Periods)
#property indicator_label2  "MA Anchored (Segment)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\MovingAverage_Anchored_Engine.mqh>

//--- Input Parameters ---
input group "MA Settings"
input int                       InpPeriod      = 20;              // Smoothing Period
input ENUM_MA_TYPE              InpMAType      = SMA;             // MA Type
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD; // Price Source

input group "Anchor Settings"
input ENUM_ANCHOR_PERIOD        InpAnchor      = ANCHOR_SESSION;  // Reset Anchor Period
input string                    InpCustomStart = "09:00";   // Custom Session Start (HH:MM)
input string                    InpCustomEnd   = "18:00";   // Custom Session End (HH:MM)

//--- Indicator Buffers ---
double    BufferMA_Odd[];
double    BufferMA_Even[];

//--- Global calculator object ---
CMovingAverageAnchoredCalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMA_Odd,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferMA_Even, INDICATOR_DATA);
   ArraySetAsSeries(BufferMA_Odd,  false);
   ArraySetAsSeries(BufferMA_Even, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- Factory Logic
   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CMovingAverageAnchoredCalculator_HA();
     }
   else
     {
      g_calculator = new CMovingAverageAnchoredCalculator();
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriod, InpMAType, InpAnchor, InpCustomStart, InpCustomEnd))
     {
      Print("Failed to initialize Moving Average Anchored Calculator.");
      return(INIT_FAILED);
     }

//--- Dynamically set the indicator short name
   string ma_name = EnumToString(InpMAType);
   StringToUpper(ma_name);
   string anchor_name = EnumToString(InpAnchor);
   string short_name = StringFormat("MA Anch%s(%s,%s,%d)",
                                    (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""),
                                    ma_name, StringSubstr(anchor_name, 7), InpPeriod);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, short_name);
   PlotIndexSetString(1, PLOT_LABEL, short_name + " (Segment)");

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpPeriod - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

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
   if(rates_total < InpPeriod + 5)
      return(0);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Force standard chronological indexing for state-safety
   ArraySetAsSeries(time, false);
   ArraySetAsSeries(open, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);

//--- Determine best volume array (Use Real Volume if available, otherwise fallback to Tick Volume)
   long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

//--- Route calculations dynamically to support volume-weighted types (VWMA)
   if(volume_limit > 0)
     {
      g_calculator.Calculate(rates_total, prev_calculated, price_type, time, open, high, low, close, volume, BufferMA_Odd, BufferMA_Even);
     }
   else
     {
      g_calculator.Calculate(rates_total, prev_calculated, price_type, time, open, high, low, close, tick_volume, BufferMA_Odd, BufferMA_Even);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
