//+------------------------------------------------------------------+
//|                                            AlphaBeta_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Rolling Alpha & Beta (Multi-Timeframe)."
#property description "Displays Higher Timeframe Performance vs Benchmark."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Dynamic Plot Styling (Default is Histogram for Alpha)
// Will be adjusted in OnInit based on Mode
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

CMathStatisticsCalculator *g_stats;
string g_bench_symbol;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
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
      // Self-reference: Flat line
      return INIT_SUCCEEDED;
     }
   if(!SymbolSelect(g_bench_symbol, true))
      return INIT_FAILED;

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
   if(_Symbol == g_bench_symbol)
      return rates_total; // Skip if self

// 1. Fetch HTF Data (Asset)
   int htf_bars = iBars(_Symbol, InpTimeframe);
   if(htf_bars < InpLookback + 5)
      return 0;

   int count = MathMin(htf_bars, 3000);

   ArraySetAsSeries(h_asset_t, false);
   ArraySetAsSeries(h_asset_c, false);

   if(CopyTime(_Symbol, InpTimeframe, 0, count, h_asset_t) != count)
      return 0;
   if(CopyClose(_Symbol, InpTimeframe, 0, count, h_asset_c) != count)
      return 0;

// 2. Calc on HTF
   if(ArraySize(h_res) != count)
      ArrayResize(h_res, count);

// We skip incremental state for statistics to ensure sync accuracy on re-fetches
// Loop through fetched HTF history
   for(int i = InpLookback; i < count; i++)
     {
      // A. Extract Asset Subset (Window on HTF)
      double asset_sub[];
      ArrayResize(asset_sub, InpLookback);
      for(int k=0; k<InpLookback; k++)
         asset_sub[k] = h_asset_c[i - InpLookback + 1 + k]; // Adjusted for loop

      // B. Extract Benchmark Subset (Sync by Time)
      double bench_sub[];
      ArrayResize(bench_sub, InpLookback);
      bool data_ok = true;

      for(int k=0; k<InpLookback; k++)
        {
         datetime t = h_asset_t[i - InpLookback + 1 + k];
         // Search on Benchmark TF (same as Asset TF)
         int b_idx = iBarShift(g_bench_symbol, InpTimeframe, t, false);

         if(b_idx < 0)
           {
            data_ok=false;
            break;
           }

         double vals[1];
         if(CopyClose(g_bench_symbol, InpTimeframe, b_idx, 1, vals)<=0)
           {
            data_ok=false;
            break;
           }
         bench_sub[k] = vals[0];
        }

      if(!data_ok)
        {
         h_res[i] = 0;
         continue;
        }

      // C. Compute
      double asset_ret[], bench_ret[];
      g_stats.ComputeReturns(asset_sub, asset_ret);
      g_stats.ComputeReturns(bench_sub, bench_ret);
      double beta = g_stats.CalculateBeta(asset_ret, bench_ret);

      double val = 0;
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

// 3. Map to Current M5 Chart
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
                     BufColors[i] = 0.0;
              }
           }
         else
            BufDisplay[i] = EMPTY_VALUE;
        }
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
