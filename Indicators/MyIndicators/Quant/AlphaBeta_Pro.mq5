//+------------------------------------------------------------------+
//|                                                AlphaBeta_Pro.mq5 |
//|                    Rolling Alpha & Beta Statistics               |
//|                    Copyright 2026, xxxxxxxx                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.20" // Fixed Display Logic using Unified Buffer
#property description "Rolling Alpha (Excess Return) or Beta (Volatility)."

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
      // Levels
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
     }
   else // BETA
     {
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Beta(%d)", InpLookback));
      IndicatorSetInteger(INDICATOR_DIGITS, 2);

      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_LINE);
      PlotIndexSetString(0, PLOT_LABEL, "Beta");
      // Levels
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 1.0);
     }

   bool is_forex = IsForexPair(_Symbol);
   g_bench_symbol = is_forex ? InpForexBench : InpBenchmark;

   if(_Symbol == g_bench_symbol || !SymbolSelect(g_bench_symbol, true))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int r) { if(CheckPointer(g_stats)==POINTER_DYNAMIC) delete g_stats; }

//+------------------------------------------------------------------+
//| Calculate                                                        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(rates_total < InpLookback + 5)
      return 0;

   int start = (prev_calculated > InpLookback) ? prev_calculated - 1 : InpLookback;

   for(int i = start; i < rates_total; i++)
     {
      // 1. Fetch Local Data
      double asset_sub[];
      ArrayResize(asset_sub, InpLookback);
      for(int k=0; k<InpLookback; k++)
         asset_sub[k] = close[i - InpLookback + 1 + k];

      // 2. Fetch Bench Data
      double bench_sub[];
      ArrayResize(bench_sub, InpLookback);
      bool data_ok = true;
      for(int k=0; k<InpLookback; k++)
        {
         datetime t = time[i - InpLookback + 1 + k];
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
         bench_sub[k] = vals[0];
        }

      if(!data_ok)
        {
         BufDisplay[i]=0;
         continue;
        }

      // 3. Calc Returns
      double asset_ret[], bench_ret[];
      g_stats.ComputeReturns(asset_sub, asset_ret);
      g_stats.ComputeReturns(bench_sub, bench_ret);

      double beta = g_stats.CalculateBeta(asset_ret, bench_ret);

      // 4. Output Logic
      if(InpMode == MODE_BETA)
        {
         BufDisplay[i] = beta;
         // Color Logic for Beta Line: Gold normally, maybe Red/Green if extreme?
         // Let's stick to Gold (Index 3 from property list)
         BufColors[i] = 3.0;
        }
      else // ALPHA
        {
         double a_tot = (asset_sub[InpLookback-1] - asset_sub[0]) / asset_sub[0];
         double b_tot = (bench_sub[InpLookback-1] - bench_sub[0]) / bench_sub[0];
         double alpha = g_stats.CalculateAlpha(a_tot, b_tot, beta);

         BufDisplay[i] = alpha;

         if(alpha > 0)
            BufColors[i] = 1.0;      // Lime
         else
            if(alpha < 0)
               BufColors[i] = 2.0; // Red
            else
               BufColors[i] = 0.0;
        }
     }

   return rates_total;
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
