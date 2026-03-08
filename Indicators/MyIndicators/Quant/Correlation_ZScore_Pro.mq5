//+------------------------------------------------------------------+
//|                                       Correlation_ZScore_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Correlation Breakdown Z-Score."
#property description "Measures statistical deviation of current correlation vs history."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   1

// Levels
#property indicator_level2 2.0
#property indicator_level3 -2.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot: Z-Score Histogram
#property indicator_label1  "Correl Z"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: Normal(Gray), Warning(Orange), Breakdown(Red)
#property indicator_color1  clrGray, clrOrange, clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\MathStatistics_Calculator.mqh>

//--- Parameters
input int      InpCorrPeriod     = 20;       // Short Correlation Window
input int      InpZScorePeriod   = 100;      // Baseline Window (Mean/StdDev)
input string   InpBenchmark      = "US500";  // Global Bench
input string   InpForexBench     = "DX";     // Forex Bench

//--- Buffers
double BufZ[];
double BufColors[];
double BufRho[]; // Internal: Raw Correlation

CMathStatisticsCalculator *g_stats;
string g_bench_symbol;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufZ, INDICATOR_DATA);
   SetIndexBuffer(1, BufColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufRho, INDICATOR_CALCULATIONS);

   g_stats = new CMathStatisticsCalculator();

// Auto-Detect Bench
   bool is_forex = IsForexPair(_Symbol);
   g_bench_symbol = is_forex ? InpForexBench : InpBenchmark;

   if(_Symbol == g_bench_symbol || !SymbolSelect(g_bench_symbol, true))
     {
      Print("CorrelZ Error: Benchmark invalid.");
      return INIT_FAILED;
     }

   string name = StringFormat("CorrelZ(%d/%d) vs %s", InpCorrPeriod, InpZScorePeriod, g_bench_symbol);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int r) { if(CheckPointer(g_stats)==POINTER_DYNAMIC) delete g_stats; }

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
   int lookback = InpCorrPeriod;
   if(rates_total < lookback + InpZScorePeriod + 5)
      return 0;

// 1. Calculate Raw Moving Correlation (Rho)
// Optimization: Start from specific point
   int start = (prev_calculated > lookback) ? prev_calculated - 1 : lookback;

// Calculate Rho
   for(int i = start; i < rates_total; i++)
     {
      double asset_sub[], bench_sub[];
      ArrayResize(asset_sub, lookback);
      ArrayResize(bench_sub, lookback);

      bool data_ok = true;
      for(int k=0; k<lookback; k++)
        {
         int idx = i - lookback + 1 + k;
         asset_sub[k] = close[idx]; // Asset Price

         datetime t = time[idx];
         int b_idx = iBarShift(g_bench_symbol, Period(), t, false);
         if(b_idx < 0)
           {
            data_ok=false;
            break;
           }

         double vals[1];
         if(CopyClose(g_bench_symbol, Period(), b_idx, 1, vals)<=0)
           {
            data_ok=false;
            break;
           }
         bench_sub[k] = vals[0]; // Bench Price
        }

      if(data_ok)
        {
         double a_ret[], b_ret[];
         g_stats.ComputeReturns(asset_sub, a_ret);
         g_stats.ComputeReturns(bench_sub, b_ret);
         BufRho[i] = g_stats.CalculateCorrelation(a_ret, b_ret);
        }
      else
        {
         BufRho[i] = 0; // Or previous
        }
     }

// 2. Calculate Z-Score of Rho
// We need N periods of Rho history
   int z_start = MathMax(start, lookback + InpZScorePeriod);

   for(int i = z_start; i < rates_total; i++)
     {
      // Calculate Mean and StdDev of BufRho over InpZScorePeriod ending at i
      double sum=0, sum_sq=0;
      for(int k=0; k<InpZScorePeriod; k++)
        {
         double val = BufRho[i-k];
         sum += val;
         sum_sq += val*val;
        }

      double mean = sum / InpZScorePeriod;
      double var = (sum_sq - (sum*sum)/InpZScorePeriod) / InpZScorePeriod; // Pop var approx
      double std = MathSqrt(var);

      if(std > 1.0e-9)
         BufZ[i] = (BufRho[i] - mean) / std;
      else
         BufZ[i] = 0.0;

      // Coloring
      double z = BufZ[i];
      if(z > 2.0 || z < -2.0)
         BufColors[i] = 2.0; // Red (Breakdown/Anomaly)
      else
         if(z > 1.5 || z < -1.5)
            BufColors[i] = 1.0; // Orange (Warning)
         else
            BufColors[i] = 0.0; // Gray (Normal)
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsForexPair(string sym)
  {
// Safety: If symbol IS one of the benchmarks, we don't classify it as generic forex pair here
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
