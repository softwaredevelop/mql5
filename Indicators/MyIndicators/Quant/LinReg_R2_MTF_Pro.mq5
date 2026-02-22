//+------------------------------------------------------------------+
//|                                            LinReg_R2_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "R-Squared & Slope (Multi-Timeframe)."
#property description "Measures Trend Quality of higher timeframe."

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   2

// Levels for R2
#property indicator_level1 0.7
#property indicator_level2 0.3
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT
#property indicator_maximum 1.0
#property indicator_minimum 0.0

// Plot 1: R-Squared (Histogram)
#property indicator_label1  "R2 MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: Chop(Gray), Weak(Orange), Strong(Lime)
#property indicator_color1  clrGray, clrOrange, clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// Plot 2: Slope (Optional Line - Hidden by default usually, but useful)
// Let's keep it visible or accessible
#property indicator_label2  "Slope MTF"
#property indicator_type2   DRAW_NONE // Hidden by default, data window only
#property indicator_color2  clrGold

#include <MyIncludes\LinearRegression_Calculator.mqh>

//--- Parameters
input ENUM_TIMEFRAMES   InpTimeframe   = PERIOD_H1;    // Target Timeframe
input int               InpPeriod      = 20;           // Regression Period
input double            InpTrendLevel  = 0.7;          // Strong Trend Level (R2)

//--- Buffers
double BufR2[];
double BufColors[];
double BufSlope[];
double BufForecast[]; // Placeholder for calc

//--- Internal HTF Data
double h_open[], h_high[], h_low[], h_close[];
double h_s[], h_r2[], h_f[]; // HTF Results
datetime h_time[];

CLinearRegressionCalculator *g_calc;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpTimeframe <= Period() && InpTimeframe!=PERIOD_CURRENT)
      Print("Warning: Target Timeframe should be > Current for proper MTF usage.");

   SetIndexBuffer(0, BufR2, INDICATOR_DATA);
   SetIndexBuffer(1, BufColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufSlope, INDICATOR_DATA);
   SetIndexBuffer(3, BufForecast, INDICATOR_CALCULATIONS);

   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string name = StringFormat("R2 MTF %s(%d)", tf_name, InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

   g_calc = new CLinearRegressionCalculator();
   if(!g_calc.Init(InpPeriod))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int r) { if(CheckPointer(g_calc)==POINTER_DYNAMIC) delete g_calc; }

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
// 1. Fetch HTF Data
   int htf_bars = iBars(_Symbol, InpTimeframe);
   if(htf_bars < InpPeriod + 1)
      return 0;

   int count = MathMin(htf_bars, 3000);

// Set to Non-Series (Chronological)
   ArraySetAsSeries(h_time, false);
   ArraySetAsSeries(h_open, false);
   ArraySetAsSeries(h_high, false);
   ArraySetAsSeries(h_low, false);
   ArraySetAsSeries(h_close, false);

   if(CopyTime(_Symbol, InpTimeframe, 0, count, h_time) != count)
      return 0;
   if(CopyOpen(_Symbol, InpTimeframe, 0, count, h_open) != count)
      return 0;
   if(CopyHigh(_Symbol, InpTimeframe, 0, count, h_high) != count)
      return 0;
   if(CopyLow(_Symbol, InpTimeframe, 0, count, h_low) != count)
      return 0;
   if(CopyClose(_Symbol, InpTimeframe, 0, count, h_close) != count)
      return 0;

// 2. Calc on HTF
   if(ArraySize(h_s) != count)
     {
      ArrayResize(h_s, count);
      ArrayResize(h_r2, count);
      ArrayResize(h_f, count);
     }

// Running Calculator on HTF Arrays
// Note: CalcState expects OHLC
   g_calc.CalculateState(count, 0, h_open, h_high, h_low, h_close, PRICE_CLOSE, h_s, h_r2, h_f);

// 3. Map to Current Chart
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, InpTimeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = count - 1 - shift_htf;

         if(idx_htf >= 0 && idx_htf < count)
           {
            double r2 = h_r2[idx_htf];
            double sl = h_s[idx_htf];

            BufR2[i] = r2;
            BufSlope[i] = sl;

            // Color Logic
            if(r2 >= InpTrendLevel)
               BufColors[i] = 2.0; // Lime (Strong)
            else
               if(r2 <= 0.3)
                  BufColors[i] = 0.0; // Gray (Chop)
               else
                  BufColors[i] = 1.0; // Orange (Weak)
           }
         else
           {
            BufR2[i] = EMPTY_VALUE;
            BufSlope[i] = EMPTY_VALUE;
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
