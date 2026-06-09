//+------------------------------------------------------------------+
//|                                                   EScore_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Added EMA Signal Line to filter out noise
#property description "Professional E-Score (Ehlers Smoother Z-Score)."
#property description "5-Zone logic: Neutral, Flow (Bull/Bear), Extreme (Bull/Bear)"
#property indicator_separate_window
#property indicator_buffers 3  // Upgraded to 3 buffers for Signal Line support
#property indicator_plots   2  // 2 Plots (Histogram + Signal Line)

//--- Institutional Levels Configuration
#property indicator_level1 2.5
#property indicator_level2 2.0
#property indicator_level3 1.5
#property indicator_level4 -1.5
#property indicator_level5 -2.0
#property indicator_level6 -2.5

#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: Color Histogram (5-Zone Thermal Palette)
#property indicator_label1  "E-Score"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrCoral, clrOrangeRed, clrLightSkyBlue, clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Smoothed Signal Line (Filters high-frequency noise)
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGold
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\EScore_Calculator.mqh>

//--- Input Parameters
input ENUM_SMOOTHER_TYPE        InpSmootherType = SUPERSMOOTHER;  // Underlying Smoother
input int                       InpPeriod       = 20;              // Volatility Lookback
input int                       InpSignalPeriod = 5;               // Signal Line Smoothing (EMA)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD; // Source Price

//--- Buffers
double ExtEScoreBuffer[];
double ExtColorsBuffer[];
double ExtSignalBuffer[]; // New Signal Line Buffer

//--- Global Engine
CEScoreCalculator *g_calc;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, ExtEScoreBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtColorsBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, ExtSignalBuffer, INDICATOR_DATA);

   ArraySetAsSeries(ExtEScoreBuffer, false);
   ArraySetAsSeries(ExtColorsBuffer, false);
   ArraySetAsSeries(ExtSignalBuffer, false);

   string name = (InpSmootherType == SUPERSMOOTHER) ? "SuperSmoother" : "UltimateSmoother";
   string short_name = StringFormat("E-Score Pro (%s, %d, %d)", name, InpPeriod, InpSignalPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

   bool use_ha = (InpSourcePrice <= PRICE_HA_CLOSE);

   g_calc = new CEScoreCalculator();
   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpPeriod, InpSmootherType, use_ha))
     {
      Print("Error: Failed to initialize EScore Calculator.");
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
   if(rates_total < InpPeriod + 5)
      return 0;

// Convert custom HA price mapping back to standard ENUM_APPLIED_PRICE
   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- 1. Calculate Core Mathematical Values (O(1) Engine)
   g_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, ExtEScoreBuffer);

//--- 2. Calculate Signal Line (Exponential Smoothing of E-Score)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   double pr = 2.0 / (double)(InpSignalPeriod + 1.0);

   for(int i = start; i < rates_total; i++)
     {
      double v = ExtEScoreBuffer[i];

      //--- 5-Zone Color Mapping Loop
      if(v >= 2.0)
         ExtColorsBuffer[i] = 2.0; // Bull Extreme (Hot) -> OrangeRed
      else
         if(v >= 1.5)
            ExtColorsBuffer[i] = 1.0; // Bull Flow (Warming) -> Coral
         else
            if(v <= -2.0)
               ExtColorsBuffer[i] = 4.0; // Bear Extreme (Freezing) -> DeepSkyBlue
            else
               if(v <= -1.5)
                  ExtColorsBuffer[i] = 3.0; // Bear Flow (Cooling) -> LightSkyBlue
               else
                  ExtColorsBuffer[i] = 0.0; // Noise -> Gray

      //--- EMA Calculation for Signal Line
      if(i == 0)
         ExtSignalBuffer[i] = v;
      else
         if(i < InpPeriod)
            ExtSignalBuffer[i] = v; // Seed period
         else
            ExtSignalBuffer[i] = v * pr + ExtSignalBuffer[i-1] * (1.0 - pr);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
