//+------------------------------------------------------------------+
//|                                                  VHF_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Vertical Horizontal Filter (Multi-Timeframe)."
#property description "Displays HTF Trend Intensity on current chart."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Levels
#property indicator_level1 0.3
#property indicator_level2 0.4
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot: VHF Line
#property indicator_label1  "VHF MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrDodgerBlue, clrGold
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\VHF_Calculator.mqh>

//--- Input Parameters
input ENUM_TIMEFRAMES   InpTimeframe   = PERIOD_H1;    // Target Timeframe
input int               InpPeriod      = 28;           // VHF Period
input ENUM_VHF_MODE     InpMode        = VHF_MODE_CLOSE_ONLY;
input ENUM_APPLIED_PRICE InpPrice      = PRICE_CLOSE;

//--- Buffers (Visual)
double BufVHF[];
double BufColor[];

//--- Internal arrays for HTF data
double h_vhf[]; // Calculated VHF on HTF
datetime h_time[]; // HTF Time index
double h_open[], h_high[], h_low[], h_close[];

//--- Calculator
CVHFCalculator *g_calc;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
// Validate Timeframe
   if(InpTimeframe <= Period())
     {
      if(InpTimeframe != Period()) // Only warn if strictly smaller
         Print("Warning: Target Timeframe should be > Current Timeframe for MTF mode.");
     }

   SetIndexBuffer(0, BufVHF, INDICATOR_DATA);
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX);

   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string name = StringFormat("VHF MTF %s(%d)", tf_name, InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   g_calc = new CVHFCalculator();
   if(!g_calc.Init(InpPeriod, InpMode))
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
// 1. Determine require bars on HTF
   int htf_bars = iBars(_Symbol, InpTimeframe);
   if(htf_bars < InpPeriod)
      return 0;

// Sync logic: Fetch all needed HTF data
// Optimization: Don't re-allocate if not needed, but Arrays for Copy need handling.
// Dynamic resizing handled by Copy functions generally.

// Standard MTF Pattern:
// A. Copy HTF OHLC
// B. Calculate Indicator on HTF Arrays
// C. Loop Current Chart and Map Time -> HTF Index -> Value

// A. Copy
// We fetch 'htf_bars' or a limit. Let's fetch last 2000 HTF bars for performance.
   int count = MathMin(htf_bars, 3000);

// Using ArraySetAsSeries = false (Oldest first) for Calculator compatibility
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

// B. Calculate on HTF
   if(ArraySize(h_vhf) != count)
      ArrayResize(h_vhf, count);

   g_calc.Calculate(count, 0, InpPrice, h_open, h_high, h_low, h_close, h_vhf);

// C. Map to Current Chart
// Optimization: Only update from prev_calculated
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, InpTimeframe, t, false);

      if(shift_htf >= 0)
        {
         // Convert Series Shift to Array Index
         int idx_htf = count - 1 - shift_htf;

         if(idx_htf >= 0 && idx_htf < count)
           {
            double val = h_vhf[idx_htf];
            BufVHF[i] = val;

            // Color Logic
            if(val > 0.40)
               BufColor[i] = 2.0;
            else
               if(val > 0.30)
                  BufColor[i] = 1.0;
               else
                  BufColor[i] = 0.0;
           }
         else
           {
            BufVHF[i] = EMPTY_VALUE;
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
