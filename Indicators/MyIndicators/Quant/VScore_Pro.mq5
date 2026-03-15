//+------------------------------------------------------------------+
//|                                                  VScore_Pro.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.10" // Simplified 5-Zone Thermal Heatmap
#property description "Professional V-Score (VWAP Z-Score)."
#property description "5-Zone logic: Neutral, Flow (Bull/Bear), Extreme (Bull/Bear)"

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Institutional Levels Configuration
#property indicator_level1 2.5
#property indicator_level2 2.0
#property indicator_level3 1.5   // Point of No Return
#property indicator_level4 -1.5  // Point of No Return
#property indicator_level5 -2.0
#property indicator_level6 -2.5

// Level Colors & Styles
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot: Color Histogram (5-Zone Thermal Palette)
#property indicator_label1  "V-Score"
#property indicator_type1   DRAW_COLOR_HISTOGRAM

// 5-Color Palette:
// 0: Noise/Neutral     (Gray)
// 1: Bull Flow         (Coral - warming up)
// 2: Bull Extreme      (OrangeRed - hot/overbought)
// 3: Bear Flow         (LightSkyBlue - cooling down)
// 4: Bear Extreme      (DeepSkyBlue - freezing/oversold)
#property indicator_color1  clrGray, clrCoral, clrOrangeRed, clrLightSkyBlue, clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\VScore_Calculator.mqh>

//--- Input Parameters
input int              InpPeriod         = 20;             // Volatility Lookback
input ENUM_VWAP_PERIOD InpVWAPReset      = PERIOD_SESSION; // VWAP Anchor

//--- Buffers
double ExtVScoreBuffer[];
double ExtColorsBuffer[];

//--- Global Engine
CVScoreCalculator *g_calc;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, ExtVScoreBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtColorsBuffer, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(ExtVScoreBuffer, false);
   ArraySetAsSeries(ExtColorsBuffer, false);

   string name = StringFormat("V-Score Pro(%d)", InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

   g_calc = new CVScoreCalculator();
   if(!g_calc.Init(InpPeriod, InpVWAPReset))
     {
      Print("Error: Failed to initialize VScore Calculator.");
      return INIT_FAILED;
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calc) == POINTER_DYNAMIC)
      delete g_calc;
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

// 1. Calculate Core Mathematical Values (O(1) Engine)
   g_calc.Calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, ExtVScoreBuffer);

// 2. Simplified 5-Zone Color Mapping Loop
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
     {
      double v = ExtVScoreBuffer[i];

      // -- Bullish Scenarios (Price > VWAP) --
      if(v >= 2.0)
         ExtColorsBuffer[i] = 2.0; // Bull Extreme (Hot) -> OrangeRed
      else
         if(v >= 1.5)
            ExtColorsBuffer[i] = 1.0; // Bull Flow (Warming) -> Coral

         // -- Bearish Scenarios (Price < VWAP) --
         else
            if(v <= -2.0)
               ExtColorsBuffer[i] = 4.0; // Bear Extreme (Freezing) -> DeepSkyBlue
            else
               if(v <= -1.5)
                  ExtColorsBuffer[i] = 3.0; // Bear Flow (Cooling) -> LightSkyBlue

               // -- Neutral Scenario --
               else
                  ExtColorsBuffer[i] = 0.0; // Noise -> Gray
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
