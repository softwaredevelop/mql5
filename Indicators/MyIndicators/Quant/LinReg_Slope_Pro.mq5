//+------------------------------------------------------------------+
//|                                             LinReg_Slope_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.01" // Increased decimal digits precision to show micro-pip fluctuations in Data Window
#property description "Linear Regression Slope. Measures the exact direction and velocity of the trend."
#property description "Features a zero-center colored histogram (Green = Bullish, Red = Bearish)."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Levels (Zero line gravity pivot)
#property indicator_level1 0.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: Slope Histogram (Swapped Bull/Bear Thermal Palette)
#property indicator_label1  "Slope"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: 0 = Neutral (Gray), 1 = Bullish (MediumSeaGreen), 2 = Bearish (Tomato)
#property indicator_color1  clrGray, clrMediumSeaGreen, clrTomato
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
input ENUM_APPLIED_PRICE InpPrice        = PRICE_CLOSE;     // Applied Price (Standard Mode)

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

//--- FIXED: Set dynamic decimal digits to match symbol precision + 2 (EURUSD = 7 digits) to show micro-pip details
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
      double sl = s[i];
      BufSlope[i] = sl;

      // Color Logic based on slope direction:
      if(sl > 0.0)
         BufColors[i] = 1.0;
      else
         if(sl < 0.0)
            BufColors[i] = 2.0;
         else
            BufColors[i] = 0.0;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
