//+------------------------------------------------------------------+
//|                                             LinReg_Slope_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.20" // Refactored with dynamic 5-Zone hybrid R2-based thermal color matrix (Standard aligned)
#property description "Linear Regression Slope. Measures the exact direction and velocity of the trend."
#property description "Features a clean separate window colored histogram with 5-zone trend integrity filtering."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Plot 1: Slope Histogram (Swapped Bull/Bear Thermal Palette)
#property indicator_label1  "Slope"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors:
// 0 = Chop/Noise (Gray)
// 1 = Bull Climax / Strong (MediumSeaGreen)
// 2 = Bull Flow / Weak (PaleGreen)
// 3 = Bear Climax / Strong (Crimson)
// 4 = Bear Flow / Weak (LightCoral)
#property indicator_color1  clrGray, clrMediumSeaGreen, clrPaleGreen, clrCrimson, clrLightCoral
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\LinearRegression_Calculator.mqh>

enum ENUM_CANDLE_SOURCE
  {
   SOURCE_STANDARD,
   SOURCE_HEIKIN_ASHI
  };

//--- Parameters
input group                     "Slope Settings"
input int                InpPeriod       = 20;              // Regression Period (N)
input ENUM_CANDLE_SOURCE InpSource       = SOURCE_STANDARD;  // Candle Source
input ENUM_APPLIED_PRICE InpPrice        = PRICE_CLOSE;     // Applied Price (Standard)
input double             InpTrendLevel   = 0.7;             // Strong Trend Level (R2 Threshold)

//--- Buffers
double    BufSlope[];
double    BufColors[];

CLinearRegressionCalculator *g_calc;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufSlope,  INDICATOR_DATA);
   SetIndexBuffer(1, BufColors, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(BufSlope,  false);
   ArraySetAsSeries(BufColors, false);

//--- Factory Logic for HA support
   bool use_ha = (InpSource == SOURCE_HEIKIN_ASHI);
   if(use_ha)
      g_calc = new CLinearRegressionCalculator_HA();
   else
      g_calc = new CLinearRegressionCalculator();

   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpPeriod))
     {
      Print("Failed to initialize Linear Regression Calculator.");
      return INIT_FAILED;
     }

   string type = use_ha ? " HA" : "";
   string name = StringFormat("LinReg Slope%s(%d)", type, InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   PlotIndexSetString(0, PLOT_LABEL, "Slope");

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod);

//--- Set dynamic decimal digits to match symbol precision + 2 (EURUSD = 7 digits) to show micro-pip details
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   if(CheckPointer(g_calc) != POINTER_INVALID)
      delete g_calc;
  }

//+------------------------------------------------------------------+
//| Calculate                                                        |
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

   if(CheckPointer(g_calc) == POINTER_INVALID)
      return 0;

//--- Force strict chronological indexing for state-safety on input price arrays
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

   double s[], r2[], f[];
   ArrayResize(s, rates_total);
   ArrayResize(r2, rates_total);
   ArrayResize(f, rates_total);

// Run Engine
   g_calc.CalculateState(rates_total, prev_calculated, open, high, low, close, InpPrice, s, r2, f);

   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpPeriod;

   for(int i = start; i < rates_total; i++)
     {
      double r  = r2[i];
      double sl = s[i];
      BufSlope[i] = sl;

      // Hybrid 5-Zone Color Matrix:
      // R2 <= 0.30 -> Index 0: Gray (Neutral Chop)
      // Slope >= 0 and R2 >= InpTrendLevel -> Index 1: MediumSeaGreen (Strong Bullish)
      // Slope >= 0 and 0.30 < R2 < InpTrendLevel -> Index 2: PaleGreen (Weak Bullish)
      // Slope < 0 and R2 >= InpTrendLevel -> Index 3: Crimson (Strong Bearish)
      // Slope < 0 and 0.30 < R2 < InpTrendLevel -> Index 4: LightCoral (Weak Bearish)
      if(r <= 0.3)
        {
         BufColors[i] = 0.0; // Gray
        }
      else
         if(sl >= 0.0)
           {
            if(r >= InpTrendLevel)
               BufColors[i] = 1.0; // Strong Bullish
            else
               BufColors[i] = 2.0; // Weak Bullish
           }
         else // sl < 0.0
           {
            if(r >= InpTrendLevel)
               BufColors[i] = 3.0; // Strong Bearish
            else
               BufColors[i] = 4.0; // Weak Bearish
           }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
