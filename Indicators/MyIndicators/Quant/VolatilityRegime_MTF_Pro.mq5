//+------------------------------------------------------------------+
//|                                     VolatilityRegime_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Volatility Regime (Multi-Timeframe)."
#property description "Displays Higher Timeframe ATR Ratio (Fast/Slow)."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Level 1.0
#property indicator_level1 1.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot: Regime Histogram
#property indicator_label1  "Vola Ratio MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: Contracting(Gray), Expanding(Lime)
#property indicator_color1  clrGray, clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\ATR_Calculator.mqh>

//--- Input Parameters
input ENUM_TIMEFRAMES   InpTimeframe      = PERIOD_H1;    // Target Timeframe
input int               InpPeriodFast     = 5;            // Short-term Volatility
input int               InpPeriodSlow     = 50;           // Long-term Baseline
input double            InpThreshold      = 1.0;          // Expansion Threshold

//--- Buffers
double BufRatio[];
double BufColor[];

//--- Internal HTF Data
double h_open[], h_high[], h_low[], h_close[];
datetime h_time[];

double h_atr_f[], h_atr_s[]; // HTF ATR results
double h_res[]; // HTF Ratio result

CATRCalculator *g_atr_fast;
CATRCalculator *g_atr_slow;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpTimeframe <= Period() && InpTimeframe != PERIOD_CURRENT)
     {
      Print("Warning: Target Timeframe should be > Current Timeframe.");
     }

   SetIndexBuffer(0, BufRatio, INDICATOR_DATA);
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX);

   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string name = StringFormat("VolaRegime MTF %s(%d/%d)", tf_name, InpPeriodFast, InpPeriodSlow);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   g_atr_fast = new CATRCalculator();
   if(!g_atr_fast.Init(InpPeriodFast, ATR_POINTS))
      return INIT_FAILED;

   g_atr_slow = new CATRCalculator();
   if(!g_atr_slow.Init(InpPeriodSlow, ATR_POINTS))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   if(CheckPointer(g_atr_fast)==POINTER_DYNAMIC)
      delete g_atr_fast;
   if(CheckPointer(g_atr_slow)==POINTER_DYNAMIC)
      delete g_atr_slow;
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
// 1. Fetch HTF Data
   int htf_bars = iBars(_Symbol, InpTimeframe);
   if(htf_bars < InpPeriodSlow + 10)
      return 0;

   int count = MathMin(htf_bars, 3000);

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
   if(ArraySize(h_atr_f) != count)
     {
      ArrayResize(h_atr_f, count);
      ArrayResize(h_atr_s, count);
      ArrayResize(h_res, count);
     }

   g_atr_fast.Calculate(count, 0, h_open, h_high, h_low, h_close, h_atr_f);
   g_atr_slow.Calculate(count, 0, h_open, h_high, h_low, h_close, h_atr_s);

   for(int i=0; i<count; i++)
     {
      if(h_atr_s[i] > 0)
         h_res[i] = h_atr_f[i] / h_atr_s[i];
      else
         h_res[i] = 1.0;
     }

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
            double val = h_res[idx_htf];
            BufRatio[i] = val;

            // Color Logic
            if(val >= InpThreshold)
               BufColor[i] = 1.0; // Lime
            else
               BufColor[i] = 0.0; // Gray
           }
         else
           {
            BufRatio[i] = EMPTY_VALUE;
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
