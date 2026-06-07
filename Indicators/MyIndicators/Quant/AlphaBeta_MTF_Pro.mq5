//+------------------------------------------------------------------+
//|                                            AlphaBeta_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.30" // Live-updating forming bar with O(1) performance
#property description "Rolling Alpha & Beta (Multi-Timeframe) with real-time forming bar calculation."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Dynamic Plot Styling (Default is Histogram for Alpha)
#property indicator_label1  "Value MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrLime, clrRed, clrGold
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\MathStatistics_Calculator.mqh>

enum ENUM_AB_MODE { MODE_ALPHA, MODE_BETA };

//--- Parameters
input ENUM_TIMEFRAMES InpTimeframe    = PERIOD_H1;  // Target Timeframe
input ENUM_AB_MODE    InpMode         = MODE_ALPHA; // Calculation Mode
input int             InpLookback     = 60;         // Rolling Window (Bars)
input string          InpBenchmark    = "US500";    // Global Bench
input string          InpForexBench   = "DX";       // Forex Bench

//--- Buffers
double BufDisplay[];
double BufColors[];

//--- Internal HTF Data
double h_asset_c[];
double h_bench_c[];
datetime h_asset_t[];
// HTF Results
double h_res[];

//--- Global HTF State Tracking
datetime g_last_htf_time  = 0;
int      g_htf_count      = 0;
bool     g_data_ready     = false;

CMathStatisticsCalculator *g_stats;
string g_bench_symbol;

//+------------------------------------------------------------------+
//| EnsureHTFDataReady (Robust MTF history loading helper)           |
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
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_last_htf_time = 0;
   g_htf_count = 0;
   g_data_ready = false;

   if(InpTimeframe <= Period() && InpTimeframe != PERIOD_CURRENT)
     {
      Print("Warning: Target Timeframe should be > Current.");
     }

   SetIndexBuffer(0, BufDisplay, INDICATOR_DATA);
   SetIndexBuffer(1, BufColors, INDICATOR_COLOR_INDEX);

// Configure Mode
   string name;
   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);

   if(InpMode == MODE_ALPHA)
     {
      name = StringFormat("Alpha MTF %s", tf_name);
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
      PlotIndexSetString(0, PLOT_LABEL, "Alpha");
      IndicatorSetInteger(INDICATOR_DIGITS, 4);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
     }
   else
     {
      name = StringFormat("Beta MTF %s", tf_name);
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_LINE);
      PlotIndexSetString(0, PLOT_LABEL, "Beta");
      IndicatorSetInteger(INDICATOR_DIGITS, 2);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 1.0);
     }
   IndicatorSetString(INDICATOR_SHORTNAME, name);

   g_stats = new CMathStatisticsCalculator();

// Benchmark Logic
   bool is_forex = IsForexPair(_Symbol);
   g_bench_symbol = is_forex ? InpForexBench : InpBenchmark;

   if(_Symbol == g_bench_symbol)
     {
      return INIT_SUCCEEDED; // Self-reference: Flat line
     }

   if(!SymbolSelect(g_bench_symbol, true))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   if(CheckPointer(g_stats) == POINTER_DYNAMIC)
      delete g_stats;
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
   if(_Symbol == g_bench_symbol)
      return rates_total; // Skip if self

//--- Ensure HTF history is ready
   int required_bars = InpLookback + 10;
   if(!EnsureHTFDataReady(_Symbol, InpTimeframe, required_bars) ||
      !EnsureHTFDataReady(g_bench_symbol, InpTimeframe, required_bars))
     {
      g_data_ready = false;
      return 0; // Wait for next tick to let history load
     }

//--- 1. Check if a new HTF bar has formed
   datetime htf_time_current = iTime(_Symbol, InpTimeframe, 0);
   bool htf_updated = (htf_time_current != g_last_htf_time);

   if(htf_updated || prev_calculated == 0)
     {
      g_last_htf_time = htf_time_current;

      int htf_bars = iBars(_Symbol, InpTimeframe);
      if(htf_bars < InpLookback + 5)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 3000);

      ArrayResize(h_asset_t, g_htf_count);
      ArrayResize(h_asset_c, g_htf_count);

      if(CopyTime(_Symbol, InpTimeframe, 0, g_htf_count, h_asset_t) != g_htf_count ||
         CopyClose(_Symbol, InpTimeframe, 0, g_htf_count, h_asset_c) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      //--- 2. High-Performance Linear Price Alignment for HTF Benchmark
      ArrayResize(h_bench_c, g_htf_count);
      for(int i = 0; i < g_htf_count; i++)
        {
         int b_idx = iBarShift(g_bench_symbol, InpTimeframe, h_asset_t[i], false);
         if(b_idx >= 0)
           {
            h_bench_c[i] = iClose(g_bench_symbol, InpTimeframe, b_idx);
           }
         else
           {
            h_bench_c[i] = (i > 0) ? h_bench_c[i-1] : h_asset_c[i];
           }
        }

      //--- 3. Calculate Alpha & Beta Statistics on HTF (Closed bars only!)
      //--- Notice the limit is 'g_htf_count - 1' (excluding the live forming bar)
      if(ArraySize(h_res) != g_htf_count)
         ArrayResize(h_res, g_htf_count);

      for(int i = InpLookback; i < g_htf_count - 1; i++)
        {
         // Extract Asset Subset via fast memory copy
         double asset_sub[];
         ArrayResize(asset_sub, InpLookback);
         if(ArrayCopy(asset_sub, h_asset_c, 0, i - InpLookback + 1, InpLookback) < InpLookback)
           {
            h_res[i] = 0.0;
            continue;
           }

         // Extract Benchmark Subset via fast memory copy
         double bench_sub[];
         ArrayResize(bench_sub, InpLookback);
         if(ArrayCopy(bench_sub, h_bench_c, 0, i - InpLookback + 1, InpLookback) < InpLookback)
           {
            h_res[i] = 0.0;
            continue;
           }

         // Compute Returns
         double asset_ret[], bench_ret[];
         g_stats.ComputeReturns(asset_sub, asset_ret);
         g_stats.ComputeReturns(bench_sub, bench_ret);
         double beta = g_stats.CalculateBeta(asset_ret, bench_ret);

         double val = 0.0;
         if(InpMode == MODE_BETA)
           {
            val = beta;
           }
         else
           {
            double a_tot = (asset_sub[InpLookback-1] - asset_sub[0]) / asset_sub[0];
            double b_tot = (bench_sub[InpLookback-1] - bench_sub[0]) / bench_sub[0];
            val = g_stats.CalculateAlpha(a_tot, b_tot, beta);
           }
         h_res[i] = val;
        }

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 4. Live Update for the Current Forming HTF Bar (Index: g_htf_count - 1) on every tick!
   int live_idx = g_htf_count - 1;
   if(live_idx >= InpLookback)
     {
      // Dynamic update of current bid prices for the forming HTF bar
      h_asset_c[live_idx] = iClose(_Symbol, InpTimeframe, 0);

      int b_idx = iBarShift(g_bench_symbol, InpTimeframe, h_asset_t[live_idx], false);
      if(b_idx >= 0)
        {
         h_bench_c[live_idx] = iClose(g_bench_symbol, InpTimeframe, b_idx);
        }
      else
        {
         h_bench_c[live_idx] = h_asset_c[live_idx];
        }

      // Perform single-bar calculation in O(1)
      double asset_sub[];
      ArrayResize(asset_sub, InpLookback);
      if(ArrayCopy(asset_sub, h_asset_c, 0, live_idx - InpLookback + 1, InpLookback) == InpLookback)
        {
         double bench_sub[];
         ArrayResize(bench_sub, InpLookback);
         if(ArrayCopy(bench_sub, h_bench_c, 0, live_idx - InpLookback + 1, InpLookback) == InpLookback)
           {
            double asset_ret[], bench_ret[];
            g_stats.ComputeReturns(asset_sub, asset_ret);
            g_stats.ComputeReturns(bench_sub, bench_ret);
            double beta = g_stats.CalculateBeta(asset_ret, bench_ret);

            double val = 0.0;
            if(InpMode == MODE_BETA)
              {
               val = beta;
              }
            else
              {
               double a_tot = (asset_sub[InpLookback-1] - asset_sub[0]) / asset_sub[0];
               double b_tot = (bench_sub[InpLookback-1] - bench_sub[0]) / bench_sub[0];
               val = g_stats.CalculateAlpha(a_tot, b_tot, beta);
              }
            h_res[live_idx] = val; // Store live-updated value
           }
        }
     }

//--- 5. Incremental Mapping of HTF results to Current Chart Timeframe (O(1) per tick)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, InpTimeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            double val = h_res[idx_htf];
            BufDisplay[i] = val;

            // Color Logic
            if(InpMode == MODE_BETA)
               BufColors[i] = 3.0; // Gold
            else
              {
               if(val > 0)
                  BufColors[i] = 1.0; // Lime
               else
                  if(val < 0)
                     BufColors[i] = 2.0; // Red
                  else
                     BufColors[i] = 0.0; // Gray
              }
           }
         else
           {
            BufDisplay[i] = EMPTY_VALUE;
           }
        }
      else
        {
         BufDisplay[i] = EMPTY_VALUE;
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| IsForexPair                                                      |
//+------------------------------------------------------------------+
bool IsForexPair(string sym)
  {
   if(sym == InpBenchmark || sym == InpForexBench)
      return false;

   if(StringFind(sym, "USD") != -1 || StringFind(sym, "EUR") != -1 ||
      StringFind(sym, "GBP") != -1 || StringFind(sym, "JPY") != -1 ||
      StringFind(sym, "CHF") != -1 || StringFind(sym, "AUD") != -1 ||
      StringFind(sym, "CAD") != -1 || StringFind(sym, "NZD") != -1 ||
      StringFind(sym, "XAU") != -1 || StringFind(sym, "XAG") != -1)
     {
      if(StringFind(sym, "XTI") != -1)
         return false;
      if(StringFind(sym, "UKO") != -1)
         return false;
      if(StringFind(sym, "USO") != -1)
         return false;
      if(StringFind(sym, "BTC") != -1)
         return false;
      if(StringFind(sym, "ETH") != -1)
         return false;
      return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
