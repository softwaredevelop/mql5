//+------------------------------------------------------------------+
//|                                            Volume_Thrust_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Volume Thrust (RVOL Ratio)."
#property description "Identifies explosive volume acceleration across timeframes."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Level 1.0 (Equilibrium)
#property indicator_level1 1.0
#property indicator_level2 1.5
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot: Thrust Histogram
#property indicator_label1  "Thrust"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: Low(Gray), Active(Orange), Surge(Gold)
#property indicator_color1  clrGray, clrOrange, clrGold
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\RelativeVolume_Calculator.mqh>

//--- Parameters
input ENUM_TIMEFRAMES   InpTFFast      = PERIOD_M5;    // Fast TF (Current)
input ENUM_TIMEFRAMES   InpTFSlow      = PERIOD_M15;   // Slow TF (Baseline)
input int               InpPeriod      = 20;           // RVOL Period
input double            InpSurgeLevel  = 1.5;          // Thrust Threshold

//--- Buffers
double BufThrust[];
double BufColor[];

//--- Internal HTF Data
long   h_vol[];
double h_rvol[];
datetime h_time[];

CRelativeVolumeCalculator *g_rvol_fast;
CRelativeVolumeCalculator *g_rvol_slow;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpTFSlow <= InpTFFast)
     {
      Print("Warning: Slow Timeframe must be higher than Fast Timeframe.");
     }

   SetIndexBuffer(0, BufThrust, INDICATOR_DATA);
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX);

   string name = StringFormat("Thrust(%s/%s)", StringSubstr(EnumToString(InpTFFast),7), StringSubstr(EnumToString(InpTFSlow),7));
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   g_rvol_fast = new CRelativeVolumeCalculator();
   g_rvol_fast.Init(InpPeriod);

   g_rvol_slow = new CRelativeVolumeCalculator();
   g_rvol_slow.Init(InpPeriod);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   if(CheckPointer(g_rvol_fast)==POINTER_DYNAMIC)
      delete g_rvol_fast;
   if(CheckPointer(g_rvol_slow)==POINTER_DYNAMIC)
      delete g_rvol_slow;
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

// 1. Fetch HTF Data
   int htf_bars = iBars(_Symbol, InpTFSlow);
   if(htf_bars < InpPeriod + 10)
      return 0;
   int count = MathMin(htf_bars, 3000); // Optimization limit

   ArraySetAsSeries(h_time, false);
   ArraySetAsSeries(h_vol, false);
   if(CopyTime(_Symbol, InpTFSlow, 0, count, h_time)!=count || CopyTickVolume(_Symbol, InpTFSlow, 0, count, h_vol)!=count)
      return 0;

// 2. Calculate HTF RVOL
   ArrayResize(h_rvol, count);
   g_rvol_slow.Calculate(count, 0, h_vol, h_rvol);

// 3. Main Loop
   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpPeriod;

// Need Fast Volume array (assuming current chart = Fast TF)
// If Indicator is on M1 chart but Input is M5/M15, we need to fetch Fast TF too.
// Let's assume Indicator is running ON the Fast TF chart for simplicity, or fetch both.
// Correct MTF design: Fetch BOTH if they differ from _Period.
// Simplification: Assume Current Chart = InpTFFast.

   for(int i = start; i < rates_total; i++)
     {
      double rvol_fast = 0;
      // Calculate Fast RVOL on the fly or use Calculator?
      // Since we are iterating, we can calculate for 'i' using helper
      // Note: Calculator needs full array history for accurate recurring MA.
      // But we can use the 'CalculateSingle' helper which does a simple SMA summation on the array.
      // This is O(Period) per bar. OK for M5.
      rvol_fast = g_rvol_fast.CalculateSingle(rates_total, tick_volume, i);

      // Get HTF RVOL
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, InpTFSlow, t, false);

      double rvol_slow = 1.0;
      if(shift_htf >= 0)
        {
         int idx_htf = count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < count)
            rvol_slow = h_rvol[idx_htf];
        }

      // Prevent div/0
      if(rvol_slow < 0.1)
         rvol_slow = 0.1;

      double thrust = rvol_fast / rvol_slow;
      BufThrust[i] = thrust;

      // Colors
      if(thrust > InpSurgeLevel)
         BufColor[i] = 2.0; // Gold (Surge)
      else
         if(thrust > 1.2)
            BufColor[i] = 1.0; // Orange (Active)
         else
            BufColor[i] = 0.0; // Gray
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
