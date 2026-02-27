//+------------------------------------------------------------------+
//|                                              VScore_MTF_Pro.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "V-Score (Multi-Timeframe)."
#property description "Displays HTF VWAP Deviation on current chart."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Levels
#property indicator_level1 2.0
#property indicator_level2 -2.0
#property indicator_level3 0.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot: Histogram
#property indicator_label1  "V-Score MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: Normal(Gray), Expensive(Orange), Cheap(Blue)
#property indicator_color1  clrGray, clrOrangeRed, clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\VScore_Calculator.mqh>

//--- Input Parameters
input ENUM_TIMEFRAMES   InpTimeframe   = PERIOD_H1;       // Target Timeframe
input int               InpPeriod      = 20;              // StdDev Lookback
input ENUM_VWAP_PERIOD  InpVWAPReset   = PERIOD_SESSION;  // VWAP Anchor

//--- Buffers
double BufV[];
double BufCol[];

//--- Internal HTF Data
double h_open[], h_high[], h_low[], h_close[];
long   h_vol[]; // Volume needed for VWAP!
datetime h_time[]; // Time needed for reset logic!
double h_res[]; // HTF Results

CVScoreCalculator *g_calc;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpTimeframe <= Period() && InpTimeframe != PERIOD_CURRENT)
     {
      Print("Warning: Target Timeframe should be > Current Timeframe.");
     }

   SetIndexBuffer(0, BufV, INDICATOR_DATA);
   SetIndexBuffer(1, BufCol, INDICATOR_COLOR_INDEX);

   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string name = StringFormat("V-Score MTF %s(%d)", tf_name, InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

   g_calc = new CVScoreCalculator();
   if(!g_calc.Init(InpPeriod, InpVWAPReset))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   if(CheckPointer(g_calc)==POINTER_DYNAMIC)
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
// 1. Fetch HTF Data
   int htf_bars = iBars(_Symbol, InpTimeframe);
   if(htf_bars < InpPeriod + 10)
      return 0;

   int count = MathMin(htf_bars, 3000);

   ArraySetAsSeries(h_time, false);
   ArraySetAsSeries(h_open, false);
   ArraySetAsSeries(h_high, false);
   ArraySetAsSeries(h_low, false);
   ArraySetAsSeries(h_close, false);
   ArraySetAsSeries(h_vol, false);

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
// Use Tick Volume for VWAP usually
   if(CopyTickVolume(_Symbol, InpTimeframe, 0, count, h_vol) != count)
      return 0;

// 2. Calc on HTF
   if(ArraySize(h_res) != count)
      ArrayResize(h_res, count);

// VScore Calc needs Time (for Session Reset) and Volume
   g_calc.Calculate(count, 0, h_time, h_open, h_high, h_low, h_close, h_vol, h_vol, h_res);

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
            BufV[i] = val;

            // Color Logic
            if(val >= 2.0)
               BufCol[i] = 1.0; // Red/Orange (Expensive)
            else
               if(val <= -2.0)
                  BufCol[i] = 2.0; // Blue (Cheap)
               else
                  BufCol[i] = 0.0; // Gray
           }
         else
           {
            BufV[i] = EMPTY_VALUE;
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
