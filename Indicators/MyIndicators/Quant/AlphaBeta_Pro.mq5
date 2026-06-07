//+------------------------------------------------------------------+
//|                                                AlphaBeta_Pro.mq5 |
//|                    Rolling Alpha & Beta Statistics               |
//|                    Copyright 2026, xxxxxxxx                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.30" // Optimized with incremental benchmark alignment
#property description "Rolling Alpha (Excess Return) or Beta (Volatility) aligned incrementally."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Default layout (Will be overridden in OnInit based on Mode)
#property indicator_label1  "Value"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrLime, clrRed, clrGold
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\MathStatistics_Calculator.mqh>

enum ENUM_AB_MODE { MODE_ALPHA, MODE_BETA };

//--- Parameters
input ENUM_AB_MODE InpMode           = MODE_ALPHA; // Calculation Mode
input int          InpLookback       = 60;         // Rolling Window (Bars)
input string       InpBenchmark      = "US500";    // Global Bench
input string       InpForexBench     = "DX";       // Forex Bench

//--- Buffers
double BufDisplay[]; // The Visible Output
double BufColors[];  // The Color Index

//--- Aligned benchmark close prices array
double g_bench_close[];

CMathStatisticsCalculator *g_stats;
string g_bench_symbol;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufDisplay, INDICATOR_DATA);
   SetIndexBuffer(1, BufColors, INDICATOR_COLOR_INDEX);

   g_stats = new CMathStatisticsCalculator();

// Configure Mode
   if(InpMode == MODE_ALPHA)
     {
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Alpha(%d)", InpLookback));
      IndicatorSetInteger(INDICATOR_DIGITS, 4);

      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
      PlotIndexSetString(0, PLOT_LABEL, "Alpha");
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
     }
   else // BETA
     {
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Beta(%d)", InpLookback));
      IndicatorSetInteger(INDICATOR_DIGITS, 2);

      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_LINE);
      PlotIndexSetString(0, PLOT_LABEL, "Beta");
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 1.0);
     }

   bool is_forex = IsForexPair(_Symbol);
   g_bench_symbol = is_forex ? InpForexBench : InpBenchmark;

   if(_Symbol == g_bench_symbol || !SymbolSelect(g_bench_symbol, true))
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
   if(rates_total < InpLookback + 5)
      return 0;

//--- 1. Incremental Benchmark Price Alignment (O(1) complexity per tick)
   ArrayResize(g_bench_close, rates_total);
   int loop_start_sync = (prev_calculated == 0) ? 0 : prev_calculated - 1;
   if(loop_start_sync < 0)
      loop_start_sync = 0;

   for(int i = loop_start_sync; i < rates_total; i++)
     {
      int shift = iBarShift(g_bench_symbol, _Period, time[i], false);
      if(shift >= 0)
        {
         g_bench_close[i] = iClose(g_bench_symbol, _Period, shift);
        }
      else
        {
         g_bench_close[i] = (i > 0) ? g_bench_close[i-1] : close[i];
        }
     }

//--- 2. Main Stats Calculation
   int start = (prev_calculated > InpLookback) ? prev_calculated - 1 : InpLookback;

   for(int i = start; i < rates_total; i++)
     {
      // Extract Local Data (Optimized via lightning-fast ArrayCopy)
      double asset_sub[];
      ArrayResize(asset_sub, InpLookback);
      if(ArrayCopy(asset_sub, close, 0, i - InpLookback + 1, InpLookback) < InpLookback)
        {
         BufDisplay[i] = 0.0;
         continue;
        }

      // Extract Bench Data from pre-synchronized array (No redundant file/cache access!)
      double bench_sub[];
      ArrayResize(bench_sub, InpLookback);
      if(ArrayCopy(bench_sub, g_bench_close, 0, i - InpLookback + 1, InpLookback) < InpLookback)
        {
         BufDisplay[i] = 0.0;
         continue;
        }

      // Calc Returns
      double asset_ret[], bench_ret[];
      g_stats.ComputeReturns(asset_sub, asset_ret);
      g_stats.ComputeReturns(bench_sub, bench_ret);

      double beta = g_stats.CalculateBeta(asset_ret, bench_ret);

      // Output Logic
      if(InpMode == MODE_BETA)
        {
         BufDisplay[i] = beta;
         BufColors[i] = 3.0; // Gold line
        }
      else // ALPHA
        {
         double a_tot = (asset_sub[InpLookback-1] - asset_sub[0]) / asset_sub[0];
         double b_tot = (bench_sub[InpLookback-1] - bench_sub[0]) / bench_sub[0];
         double alpha = g_stats.CalculateAlpha(a_tot, b_tot, beta);

         BufDisplay[i] = alpha;

         if(alpha > 0)
            BufColors[i] = 1.0; // Lime
         else
            if(alpha < 0)
               BufColors[i] = 2.0; // Red
            else
               BufColors[i] = 0.0; // Gray
        }
     }

   return rates_total;
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
