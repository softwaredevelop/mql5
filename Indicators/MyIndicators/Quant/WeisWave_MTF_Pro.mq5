//+------------------------------------------------------------------+
//|                                           WeisWave_MTF_Pro.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Non-repainting MTF with live forming bar updates
#property description "Weis Wave Volume Pro (Multi-Timeframe)."
#property description "Displays Higher Timeframe Weis Waves on the current chart."
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Plot: Color Histogram
#property indicator_label1  "Wave Volume MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrDodgerBlue, clrCrimson // Index 0: Demand, Index 1: Supply
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

#include <MyIncludes\WeisWave_Calculator.mqh>

//--- Input Parameters
input ENUM_TIMEFRAMES   InpTimeframe  = PERIOD_H1;       // Target Higher Timeframe
input int               InpATRPeriod  = 14;              // ATR Sensitivity Period
input double            InpMultiplier = 2.5;             // Wave Reversal Multiplier (ATR)

//--- Buffers
double ExtWaveVolBuffer[];
double ExtColorsBuffer[];

//--- Internal HTF Data Caches
double   h_high[];
double   h_low[];
double   h_close[];
long     h_vol[];
datetime h_time[];

//--- HTF Calculator Results
double   h_res_vol[];
double   h_res_col[];

//--- Global HTF State Tracking
datetime g_last_htf_time  = 0;
int      g_htf_count      = 0;
bool     g_data_ready     = false;

CWeisWaveCalculator *g_calc;

//+------------------------------------------------------------------+
//| EnsureHTFDataReady                                               |
//+------------------------------------------------------------------+
bool EnsureHTFDataReady(const string symbol, const ENUM_TIMEFRAMES timeframe, const int required_bars)
  {
   ResetLastError();
   if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
     {
      SymbolSelect(symbol, true);
     }
   datetime times[];
   int copied = CopyTime(symbol, timeframe, 0, required_bars, times);
   return (copied >= required_bars);
  }

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_last_htf_time = 0;
   g_htf_count = 0;
   g_data_ready = false;

   if(InpTimeframe <= Period() && InpTimeframe != PERIOD_CURRENT)
     {
      Print("Warning: Target Timeframe should be higher than current timeframe.");
     }

   SetIndexBuffer(0, ExtWaveVolBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtColorsBuffer, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(ExtWaveVolBuffer, false);
   ArraySetAsSeries(ExtColorsBuffer, false);

   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string short_name = StringFormat("Weis Wave MTF %s(%d, %.1f)", tf_name, InpATRPeriod, InpMultiplier);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, 0);

   g_calc = new CWeisWaveCalculator();
   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpATRPeriod, InpMultiplier))
     {
      Print("Weis Wave MTF: Failed to initialize Calculator.");
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
//--- Ensure HTF history is synchronized and ready
   int required_bars = InpATRPeriod + 10;
   if(!EnsureHTFDataReady(_Symbol, InpTimeframe, required_bars))
     {
      g_data_ready = false;
      return 0; // Wait for next tick to let history load
     }

//--- Determine the best volume type (Real Volume vs Tick Volume)
   long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
   bool use_real_volume = (volume_limit > 0);

//--- Check if a new HTF bar has opened
   datetime htf_time_current = iTime(_Symbol, InpTimeframe, 0);
   bool htf_updated = (htf_time_current != g_last_htf_time);

   if(htf_updated || prev_calculated == 0)
     {
      g_last_htf_time = htf_time_current;

      int htf_bars = iBars(_Symbol, InpTimeframe);
      if(htf_bars < required_bars)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 3000);

      ArrayResize(h_time, g_htf_count);
      ArrayResize(h_high, g_htf_count);
      ArrayResize(h_low, g_htf_count);
      ArrayResize(h_close, g_htf_count);
      ArrayResize(h_vol, g_htf_count);

      // Fetch HTF prices
      if(CopyTime(_Symbol, InpTimeframe, 0, g_htf_count, h_time) != g_htf_count ||
         CopyHigh(_Symbol, InpTimeframe, 0, g_htf_count, h_high) != g_htf_count ||
         CopyLow(_Symbol, InpTimeframe, 0, g_htf_count, h_low) != g_htf_count ||
         CopyClose(_Symbol, InpTimeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      // Fetch HTF Volume (Tick Volume vs Real Volume)
      if(use_real_volume)
        {
         if(CopyRealVolume(_Symbol, InpTimeframe, 0, g_htf_count, h_vol) != g_htf_count)
           {
            g_data_ready = false;
            return 0;
           }
        }
      else
        {
         if(CopyTickVolume(_Symbol, InpTimeframe, 0, g_htf_count, h_vol) != g_htf_count)
           {
            g_data_ready = false;
            return 0;
           }
        }

      //--- Calculate HTF Waves on closed historical bars
      if(ArraySize(h_res_vol) != g_htf_count)
        {
         ArrayResize(h_res_vol, g_htf_count);
         ArrayResize(h_res_col, g_htf_count);
        }

      // Compute closed bars (excluding the active forming bar)
      g_calc.Calculate(g_htf_count - 1, 0, h_high, h_low, h_close, h_vol, h_res_vol, h_res_col);

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 2. Live Update for the Current Forming HTF Bar (Index: g_htf_count - 1) on every tick!
   int live_idx = g_htf_count - 1;
   if(live_idx >= 0)
     {
      double single_h[1], single_l[1], single_c[1];
      long   single_v[1];

      // Native, 100% compile-safe MQL5 1-bar copying (replaces old MQL4 iHigh/iLow/iClose)
      if(CopyHigh(_Symbol, InpTimeframe, 0, 1, single_h) == 1 &&
         CopyLow(_Symbol, InpTimeframe, 0, 1, single_l) == 1 &&
         CopyClose(_Symbol, InpTimeframe, 0, 1, single_c) == 1)
        {
         h_high[live_idx]  = single_h[0];
         h_low[live_idx]   = single_l[0];
         h_close[live_idx] = single_c[0];

         // Volume copying
         if(use_real_volume)
           {
            CopyRealVolume(_Symbol, InpTimeframe, 0, 1, single_v);
           }
         else
           {
            CopyTickVolume(_Symbol, InpTimeframe, 0, 1, single_v);
           }
         h_vol[live_idx] = single_v[0];

         // Recalculate exactly once for the live bar (O(1) complexity per tick)
         g_calc.Calculate(g_htf_count, g_htf_count - 1, h_high, h_low, h_close, h_vol, h_res_vol, h_res_col);
        }
     }

//--- 3. Incremental Mapping of HTF results to Current Chart Timeframe (O(1) per tick)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];

      // exact = false ensures robust nearest-neighbor matching for timeframe gap alignment
      int shift_htf = iBarShift(_Symbol, InpTimeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            ExtWaveVolBuffer[i] = h_res_vol[idx_htf];
            ExtColorsBuffer[i]  = h_res_col[idx_htf];
           }
         else
           {
            ExtWaveVolBuffer[i] = EMPTY_VALUE;
            ExtColorsBuffer[i]  = EMPTY_VALUE;
           }
        }
      else
        {
         ExtWaveVolBuffer[i] = EMPTY_VALUE;
         ExtColorsBuffer[i]  = EMPTY_VALUE;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
