//+------------------------------------------------------------------+
//|                                                     RVOL_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Relative Volume Indicator."
#property description "Highlights institutional activity spikes > 2.0."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Levels
#property indicator_level1 1.0
#property indicator_level2 2.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot: RVOL Histogram (Colored)
#property indicator_label1  "RVOL"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrDodgerBlue, clrOrangeRed // Low, Normal, High
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

#include <MyIncludes\RelativeVolume_Calculator.mqh>

//--- Input Parameters
input int               InpPeriod      = 20;          // Average Volume Period
input double            InpThreshold   = 2.0;         // High Activity Threshold

//--- Buffers
double BufferRVOL[];
double BufferColors[]; // 0=Low, 1=Normal, 2=High

//--- Global Object
CRelativeVolumeCalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferRVOL, INDICATOR_DATA);
   SetIndexBuffer(1, BufferColors, INDICATOR_COLOR_INDEX);

   string name = StringFormat("RVOL(%d)", InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   g_calculator = new CRelativeVolumeCalculator();
   if(!g_calculator.Init(InpPeriod))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) == POINTER_DYNAMIC)
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
   if(rates_total < InpPeriod)
      return 0;

// 1. Calculate
// Note: RVOL uses Volume (Tick or Real). Usually Tick Volume in Forex.
   g_calculator.Calculate(rates_total, prev_calculated, tick_volume, BufferRVOL);

// 2. Color Logic
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start_index; i < rates_total; i++)
     {
      double val = BufferRVOL[i];

      if(val > InpThreshold)
         BufferColors[i] = 2.0; // High (Instituional)
      else
         if(val > 1.0)
            BufferColors[i] = 1.0; // Normal
         else
            BufferColors[i] = 0.0; // Low
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
