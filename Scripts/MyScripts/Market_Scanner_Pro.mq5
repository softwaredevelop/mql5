//+------------------------------------------------------------------+
//|                                           Market_Scanner_Pro.mq5 |
//|                    QuantScan 9.1 - Next Gen Statistics           |
//|                    Copyright 2026, xxxxxxxx                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "9.10" // Squeeze Momentum Integration
#property description "Exports 'QuantScan 9.0' dataset for LLM Analysis."
#property description "Features Advanced Statistical Filters (VHF, R2, V-Score)."
#property script_show_inputs

//--- Includes
#include <MyIncludes\TSI_Calculator.mqh>
#include <MyIncludes\MurreyMath_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\MathStatistics_Calculator.mqh>
#include <MyIncludes\RelativeVolume_Calculator.mqh>
#include <MyIncludes\SessionLevels_Calculator.mqh>
#include <MyIncludes\Metrics_Tools.mqh>
#include <MyIncludes\DataSync_Tools.mqh>
#include <MyIncludes\Squeeze_Calculator.mqh>
// NEW Integrations:
#include <MyIncludes\VHF_Calculator.mqh>
#include <MyIncludes\LinearRegression_Calculator.mqh>
#include <MyIncludes\VScore_Calculator.mqh>
#include <MyIncludes\Autocorrelation_Calculator.mqh>

//--- Input Parameters
input group "Scanner Config"
input bool     InpUseMarketWatch = false;
input string   InpSymbolList     = "EURUSD,USDJPY,GBPUSD,USDCHF,AUDUSD,XAUUSD,US500,DE40,XTIUSD,ETHUSD";
input string   InpBenchmark      = "US500";
input string   InpForexBench     = "DX";
input string   InpBrokerTimeZone = "EET (UTC+2)";
input int      InpScanHistory    = 500;

input group "Benchmark Settings"
input int      InpBetaLookback   = 60;

input group "Timeframes"
input ENUM_TIMEFRAMES InpTFFast  = PERIOD_M5;  // Layer 3 (Trigger)
input ENUM_TIMEFRAMES InpTFMiddle= PERIOD_M15; // Layer 2 (Flow)
input ENUM_TIMEFRAMES InpTFSlow  = PERIOD_H1;  // Layer 1 (Context)

input group "Metric Settings"
input int      InpVHFPeriod      = 28;   // VHF Lookback
input int      InpR2Period       = 20;   // R-Squared Lookback
input int      InpVScorePeriod   = 20;   // V-Score Period
input int      InpAutoCorrPeriod = 20;   // Autocorrelation Window
// Standard settings
input int      InpMurreyPeriod   = 64;
input int      InpATRPeriod      = 14;
input int      InpRSBars         = 24;
input int      InpRVOLPeriod     = 20;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "TSI Settings (For MTF Align)"
input int      InpTSI_Slow       = 25;
input int      InpTSI_Fast       = 13;
input int      InpTSI_Signal     = 13;

input group "Squeeze Settings"
input int      InpSqueezeLength  = 20;
input double   InpBBMult         = 2.0;
input double   InpKCMult         = 1.5;
input int      InpSqueezeMom     = 12; // NEW

//--- QuantData Struct (Updated Layout)
struct QuantData
  {
   string            timestamp;
   string            symbol;
   double            price;

   // H1 Context
   string            alpha_str;        // Alpha
   string            beta_str;         // Beta
   double            vhf;              // VHF
   double            r2;               // R-Squared
   string            zone;             // Murrey Zone

   // M15 Flow
   double            v_score;          // VWAP Z-Score
   double            autocorr;         // Lag-1 Correlation
   double            vol_regime;       // ATR(5)/ATR(50)
   string            sqz;              // Squeeze State
   double            sqz_mom;          // New
   double            m15_vhf;          // New
   double            m15_r2;           // New
   double            dist_pdh;
   double            dist_pdl;

   // M5 Trigger
   double            velocity;
   double            vol_thrust;       // M5 RVOL / M15 RVOL
   double            cost_atr;

   // Composites
   string            absorption;
   string            mtf_align;

   // Internal TSI Hist for Breadth/Align
   double            h1_tsi_hist;
   double            m15_tsi_hist;
   double            m5_tsi_hist;
  };

//--- Helper: Detect Asset Class
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
//| Helper: Get Sentiment String for TF (Extended Format)            |
//+------------------------------------------------------------------+
string GetSentimentForTF(ENUM_TIMEFRAMES tf)
  {
   if(!CDataSync::EnsureDataReady(InpBenchmark, tf, 2))
      return "N/A";
   if(!CDataSync::EnsureDataReady(InpForexBench, tf, 2))
      return "N/A";

   double u_clos[2], d_clos[2];
   if(CopyClose(InpBenchmark, tf, 1, 2, u_clos) != 2)
      return "N/A";
   if(CopyClose(InpForexBench, tf, 1, 2, d_clos) != 2)
      return "N/A";

   double u_chg = u_clos[1] - u_clos[0];
   double d_chg = d_clos[1] - d_clos[0];
   double u_pct = (u_clos[0]!=0) ? (u_chg / u_clos[0])*100.0 : 0;
   double d_pct = (d_clos[0]!=0) ? (d_chg / d_clos[0])*100.0 : 0;

   string state = "MIXED";
   if(d_chg < 0 && u_chg > 0)
      state = "RISK-ON";
   else
      if(d_chg > 0 && u_chg < 0)
         state = "RISK-OFF";
      else
         if(d_chg > 0 && u_chg > 0)
            state = "STRESS";
         else
            if(d_chg < 0 && u_chg < 0)
               state = "DEFLATION";

   string tf_name = EnumToString(tf);
   StringReplace(tf_name, "PERIOD_", "");

// FIX: Return full format string
   return StringFormat("%s: %s (US:%.2f%% DX:%.2f%%)", tf_name, state, u_pct, d_pct);
  }

//--- Forward Declarations
// Updated list of wrappers
bool FetchData(string sym, ENUM_TIMEFRAMES tf, int count, datetime &t[], double &o[], double &h[], double &l[], double &c[], long &v[]);
double Calc_ATR(const double &o[], const double &h[], const double &l[], const double &c[], int p, int idx);
string Calc_Squeeze(string sym, ENUM_TIMEFRAMES tf, const double &o[], const double &h[], const double &l[], const double &c[], int idx);
string Calc_MurreyZone(string symbol, ENUM_TIMEFRAMES tf);
double Calc_Velocity(const double &close[], double atr, int period, int idx);
double Calc_RVOL(const long &vol[], int p, int idx);
void Calc_TSI_Values(const double &o[], const double &h[], const double &l[], const double &c[], int idx, double &val, double &hist);
// New Wrappers
double Calc_VHF(const double &o[], const double &h[], const double &l[], const double &c[], int p, int idx);
double Calc_R2(const double &o[], const double &h[], const double &l[], const double &c[], int p, int idx);
double Calc_VScore(string sym, const datetime &t[], const double &o[], const double &h[], const double &l[], const double &c[], const long &v[], int p, int idx);
double Calc_AutoCorr(const double &o[], const double &h[], const double &l[], const double &c[], int p, int idx);

//+------------------------------------------------------------------+
//| Script Start                                                     |
//+------------------------------------------------------------------+
void OnStart()
  {
   string symbols[];
   int total_symbols = 0;

   if(InpUseMarketWatch)
     {
      total_symbols = SymbolsTotal(true);
      ArrayResize(symbols, total_symbols);
      for(int i=0; i<total_symbols; i++)
         symbols[i] = SymbolName(i, true);
     }
   else
     {
      string sep = ",";
      ushort u_sep = StringGetCharacter(sep, 0);
      total_symbols = StringSplit(InpSymbolList, u_sep, symbols);
     }

// --- Global Sentiment ---
   string sentiment_line = "### GLOBAL_SENTIMENT | ";
   bool has_us500 = SymbolSelect(InpBenchmark, true);
   bool has_dxy   = SymbolSelect(InpForexBench, true);
   if(has_us500 && has_dxy)
     {
      sentiment_line += GetSentimentForTF(InpTFSlow) + " | " + GetSentimentForTF(InpTFMiddle) + " | " + GetSentimentForTF(InpTFFast) + " ###";
     }
   else
      sentiment_line += "Benchmarks Missing ###";

// Sync for RS
   if(has_us500)
      CDataSync::EnsureDataReady(InpBenchmark, InpTFSlow);

   string filename = "QuantScan_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + ".csv";
   StringReplace(filename, ":", "");
   StringReplace(filename, " ", "_");

   int file_handle = FileOpen(filename, FILE_CSV|FILE_WRITE|FILE_ANSI, ";");
   if(file_handle == INVALID_HANDLE)
      return;

// --- SCAN & STORE for Breadth ---
   PrintFormat("Scanning %d symbols...", total_symbols);
   QuantData results[];
   int success_count = 0;

   for(int i=0; i<total_symbols; i++)
     {
      string sym = symbols[i];
      StringTrimLeft(sym);
      StringTrimRight(sym);
      QuantData temp_data;
      ZeroMemory(temp_data);
      if(RunQuantAnalysis(sym, temp_data))
        {
         ArrayResize(results, success_count + 1);
         results[success_count] = temp_data;
         success_count++;
        }
      else
         Print("Scan Failed: ", sym);
     }

// --- BREADTH SCORE ---
// Count TSI Bullishness across portfolio (H1 or M15?) usually Trend Context (H1) matters most for Breadth.
   int bulls = 0;
   for(int i=0; i<success_count; i++)
     {
      if(results[i].h1_tsi_hist > 0)
         bulls++; // Using H1 Histogram direction
     }
   double breadth_pct = (success_count>0) ? ((double)bulls/success_count)*100.0 : 0;
   sentiment_line += StringFormat(" BREADTH: %d/%d (%.0f%% Bullish)", bulls, success_count, breadth_pct);

// --- WRITE HEADERS ---
   FileWrite(file_handle, sentiment_line);

   string str_slow = EnumToString(InpTFSlow);
   StringReplace(str_slow, "PERIOD_", "");
   string str_mid  = EnumToString(InpTFMiddle);
   StringReplace(str_mid, "PERIOD_", "");
   string str_fast = EnumToString(InpTFFast);
   StringReplace(str_fast, "PERIOD_", "");

   string header = "TIME (" + InpBrokerTimeZone + ");SYMBOL;PRICE;";
// Layer 1
   header += StringFormat("ALPHA_%s;BETA_%s;VHF_%s;R2_%s;ZONE_%s;", str_slow, str_slow, str_slow, str_slow, str_slow);
// Layer 2
   header += StringFormat("V_SCORE_%s;AUTOCORR_%s;VOL_REGIME_%s;SQZ_%s;SQZ_MOM_%s;VHF_%s;R2_%s;DIST_PDH;DIST_PDL;", str_mid, str_mid, str_mid, str_mid, str_mid, str_mid, str_mid);
// Layer 3
   header += StringFormat("VEL_%s;VOL_THRUST;COST_ATR_%s;", str_fast, str_fast);
// Composites
   header += "ABSORPTION;MTF_ALIGN";

   FileWrite(file_handle, header);

// --- WRITE DATA ---
   for(int i=0; i<success_count; i++)
     {
      FileWrite(file_handle,
                results[i].timestamp,
                results[i].symbol,
                DoubleToString(results[i].price, (int)SymbolInfoInteger(results[i].symbol, SYMBOL_DIGITS)),
                // L1
                results[i].alpha_str,
                results[i].beta_str,
                DoubleToString(results[i].vhf, 2),
                DoubleToString(results[i].r2, 2),
                results[i].zone,
                // L2
                DoubleToString(results[i].v_score, 2),
                DoubleToString(results[i].autocorr, 2),
                DoubleToString(results[i].vol_regime, 2),
                results[i].sqz,
                DoubleToString(results[i].sqz_mom, 2),
                DoubleToString(results[i].m15_vhf, 2),
                DoubleToString(results[i].m15_r2, 2),
                DoubleToString(results[i].dist_pdh, 2),
                DoubleToString(results[i].dist_pdl, 2),
                // L3
                DoubleToString(results[i].velocity, 2),
                DoubleToString(results[i].vol_thrust, 2),
                DoubleToString(results[i].cost_atr, 2),
                // Composite
                results[i].absorption,
                results[i].mtf_align
               );
     }

   FileClose(file_handle);
   Print("Done. File: ", filename);
  }

//+------------------------------------------------------------------+
//| Core Logic                                                       |
//+------------------------------------------------------------------+
bool RunQuantAnalysis(string sym, QuantData &data)
  {
   data.timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
   StringReplace(data.timestamp, ".", ".");
   data.symbol    = sym;
   data.price     = SymbolInfoDouble(sym, SYMBOL_BID);

// =================================================================
// LAYER 1: CONTEXT (H1) - LIVE
// =================================================================
   double slow_o[], slow_h[], slow_l[], slow_c[];
   long slow_v[];
   datetime slow_t[];
   if(!FetchData(sym, InpTFSlow, InpScanHistory, slow_t, slow_o, slow_h, slow_l, slow_c, slow_v))
      return false;
   int idx_l1 = ArraySize(slow_c) - 1;

// 1. Alpha / Beta (Live)
// --- BETA / ALPHA + REL STRENGTH (Time-Synced) ---
   bool is_benchmark = (sym == InpBenchmark || sym == InpForexBench);
   if(is_benchmark)
     {
      //data.rel_strength_str="BENCH";
      data.beta_str="1.0";
      data.alpha_str="0.0";
     }
   else
     {
      string bench_sym = InpBenchmark;
      if(IsForexPair(sym) && SymbolSelect(InpForexBench, true))
         bench_sym = InpForexBench;

      // Fetch Benchmark Full History
      double b_c[], dum_o[], dum_h[], dum_l[];
      long dum_v[];
      datetime b_t[];
      if(CDataSync::EnsureDataReady(bench_sym, InpTFSlow, InpScanHistory))
        {
         if(FetchData(bench_sym, InpTFSlow, InpScanHistory, b_t, dum_o, dum_h, dum_l, b_c, dum_v))
           {
            CMathStatisticsCalculator stats;
            int h1_size = ArraySize(slow_c);
            int bench_size = ArraySize(b_c);

            // Allocate for Beta (Longer period usually)
            int lookback_beta = InpBetaLookback;
            double asset_subset[];
            ArrayResize(asset_subset, lookback_beta);
            double bench_subset[];
            ArrayResize(bench_subset, lookback_beta);

            int valid_points = 0;

            // Variables for RS Calculation (Shorter period)
            double rs_asset_start = 0, rs_bench_start = 0;
            double rs_asset_end = 0, rs_bench_end = 0;
            bool rs_start_found = false;

            // Loop backwards from current LIVE bar
            for(int k=0; k<lookback_beta; k++)
              {
               int a_idx = h1_size - 1 - k;
               if(a_idx < 0)
                  break;

               datetime a_time = slow_t[a_idx];
               int b_idx_arr = ArrayBsearch(b_t, a_time); // Binary search for time match

               // Value to store
               double a_val = slow_c[a_idx];
               double b_val = (b_idx_arr >= 0 && b_idx_arr < bench_size && b_t[b_idx_arr] == a_time) ?
                              b_c[b_idx_arr] : (k>0 ? bench_subset[lookback_beta - k] : 0);

               if(b_idx_arr >= 0 && b_idx_arr < bench_size && b_t[b_idx_arr] == a_time)
                 {
                  b_val = b_c[b_idx_arr];
                 }
               else
                 {
                  // Gap filling
                  if(k>0 && (lookback_beta-k) < lookback_beta)
                     b_val = bench_subset[lookback_beta-k]; // Next element in array (which is 'newer' since we fill from end)
                  else
                     b_val = b_c[MathMin(bench_size-1, b_idx_arr>0?b_idx_arr:0)]; // Fallback
                 }

               int sub_idx = lookback_beta - 1 - k;
               asset_subset[sub_idx] = a_val;
               bench_subset[sub_idx] = b_val;
               valid_points++;

               // --- RS Logic Capture ---
               // End Price (k=0)
               if(k==0)
                 {
                  rs_asset_end = a_val;
                  rs_bench_end = b_val;
                 }

               // Start Price (k = InpRSBars)
               if(k == InpRSBars)
                 {
                  rs_asset_start = a_val;
                  rs_bench_start = b_val;
                  rs_start_found = true;
                 }
              }

            // 1. Calc Beta/Alpha (Long Term)
            if(valid_points > lookback_beta / 2)
              {
               double asset_ret[], bench_ret[];
               stats.ComputeReturns(asset_subset, asset_ret);
               stats.ComputeReturns(bench_subset, bench_ret);

               double beta_val = stats.CalculateBeta(asset_ret, bench_ret);

               // Alpha on Beta Period
               double a_tot_beta = (asset_subset[lookback_beta-1] - asset_subset[0]) / asset_subset[0];
               double b_tot_beta = (bench_subset[lookback_beta-1] - bench_subset[0]) / bench_subset[0];
               double alpha_val = stats.CalculateAlpha(a_tot_beta, b_tot_beta, beta_val);

               data.beta_str  = DoubleToString(beta_val, 2);
               data.alpha_str = DoubleToString(alpha_val, 4);
              }
            else
              {
               data.beta_str = "0";
               data.alpha_str = "0";
              }

            // 2. Calc Relative Strength (Short Term - InpRSBars)
            //if(rs_start_found && rs_asset_start != 0 && rs_bench_start != 0)
            //  {
            //   double a_perf = (rs_asset_end - rs_asset_start) / rs_asset_start;
            //   double b_perf = (rs_bench_end - rs_bench_start) / rs_bench_start;
            //   double rel_val = (a_perf - b_perf) * 100.0;
            //data.rel_strength_str = DoubleToString(rel_val, 2) + "%";
            //}
            //else
            //  {
            //   data.rel_strength_str = "-";
            //  }
           }
        }
     }

// 2. VHF (Live)
   data.vhf = Calc_VHF(slow_o, slow_h, slow_l, slow_c, InpVHFPeriod, idx_l1);

// 3. R-Squared (Live)
   data.r2  = Calc_R2(slow_o, slow_h, slow_l, slow_c, InpR2Period, idx_l1);

// 4. Zone (Murrey)
   data.zone = Calc_MurreyZone(sym, InpTFSlow);

// 5. Calc TSI H1 (Hidden from CSV but used for MTF Align Breadth)
   double tsi_main_h1=0;
   Calc_TSI_Values(slow_o, slow_h, slow_l, slow_c, idx_l1, tsi_main_h1, data.h1_tsi_hist);

// =================================================================
// LAYER 2: FLOW (M15) - LIVE
// =================================================================
   double mid_o[], mid_h[], mid_l[], mid_c[];
   long mid_v[];
   datetime mid_t[];
   if(!FetchData(sym, InpTFMiddle, InpScanHistory, mid_t, mid_o, mid_h, mid_l, mid_c, mid_v))
      return false;
   int idx_l2 = ArraySize(mid_c) - 1;

   double mid_atr = Calc_ATR(mid_o, mid_h, mid_l, mid_c, InpATRPeriod, idx_l2);

// 1. V-Score (Live)
   data.v_score = Calc_VScore(sym, mid_t, mid_o, mid_h, mid_l, mid_c, mid_v, InpVScorePeriod, idx_l2);

// 2. Autocorrelation (Live)
   data.autocorr = Calc_AutoCorr(mid_o, mid_h, mid_l, mid_c, InpAutoCorrPeriod, idx_l2);

// 3. Vol Regime (Live)
   double atr_f = Calc_ATR(mid_o, mid_h, mid_l, mid_c, 5, idx_l2);
   double atr_s = Calc_ATR(mid_o, mid_h, mid_l, mid_c, 50, idx_l2);
   data.vol_regime = (atr_s!=0) ? atr_f/atr_s : 1.0;

// 4. Squeeze
   Calc_Squeeze_Full(sym, InpTFMiddle, mid_o, mid_h, mid_l, mid_c, idx_l2, data.sqz, data.sqz_mom);

// 5. VHF & R2 (Live)
   data.m15_vhf = Calc_VHF(mid_o, mid_h, mid_l, mid_c, InpVHFPeriod, idx_l2);
   data.m15_r2  = Calc_R2(mid_o, mid_h, mid_l, mid_c, InpR2Period, idx_l2);

// 6. Dist PDH/PDL
   CSessionLevelsCalculator sess_calc;
   if(sess_calc.Init(PERIOD_D1))
     {
      SessionLevels sl;
      if(sess_calc.GetLevels(sym, mid_t[idx_l2], sl))
        {
         data.dist_pdh = CMetricsTools::CalculateDistance(mid_c[idx_l2], sl.prev_high, mid_atr);
         data.dist_pdl = CMetricsTools::CalculateDistance(mid_c[idx_l2], sl.prev_low, mid_atr);
        }
     }

// M15 TSI for Align
   double tsi_main_m15=0;
   Calc_TSI_Values(mid_o, mid_h, mid_l, mid_c, idx_l2, tsi_main_m15, data.m15_tsi_hist);

// RVOL M15 for Thrust
   double rvol_m15 = Calc_RVOL(mid_v, InpRVOLPeriod, idx_l2);

// =================================================================
// LAYER 3: TRIGGER (M5) - LIVE
// =================================================================
   double fast_o[], fast_h[], fast_l[], fast_c[];
   long fast_v[];
   datetime fast_t[];
   if(!FetchData(sym, InpTFFast, 300, fast_t, fast_o, fast_h, fast_l, fast_c, fast_v))
      return false;
   int idx_l3 = ArraySize(fast_c) - 1;

   double fast_atr = Calc_ATR(fast_o, fast_h, fast_l, fast_c, InpATRPeriod, idx_l3);

// 1. Velocity
   data.velocity = Calc_Velocity(fast_c, fast_atr, 3, idx_l3);

// 2. Volume Thrust
   double rvol_m5 = Calc_RVOL(fast_v, InpRVOLPeriod, idx_l3);
   if(rvol_m15 > 0)
      data.vol_thrust = rvol_m5 / rvol_m15;
   else
      data.vol_thrust = 0;

// 3. Cost
   data.cost_atr = CMetricsTools::CalculateSpreadCost(sym, fast_atr);

   double tsi_main_m5 = 0;
   Calc_TSI_Values(fast_o, fast_h, fast_l, fast_c, idx_l3, tsi_main_m5, data.m5_tsi_hist);

// =================================================================
// COMPOSITES
// =================================================================

// =================================================================
// ADVANCED ABSORPTION LOGIC (Wyckoff Effort/Result)
// =================================================================
// Using Last Closed M15 Bar for pattern validation
   int idx_cl_mid = idx_l2 - 1;

   if(idx_cl_mid >= 0 && mid_atr > 0)
     {
      double body = MathAbs(mid_c[idx_cl_mid] - mid_o[idx_cl_mid]);
      double total_range = mid_h[idx_cl_mid] - mid_l[idx_cl_mid];

      // Calculate specific bar RVOL using helper
      // Note: We use a local calculator instance to be safe or reuse helper logic
      CRelativeVolumeCalculator rv_calc;
      rv_calc.Init(InpRVOLPeriod);
      double bar_rvol = rv_calc.CalculateSingle(ArraySize(mid_v), mid_v, idx_cl_mid);

      bool high_effort = (bar_rvol > 2.0);
      bool low_result  = (body < (0.35 * mid_atr)); // Stricter 35% ATR rule

      data.absorption = "NO"; // Default

      if(high_effort && low_result)
        {
         // Analyze Close Position relative to High-Low Range
         // Position 0.0 (Low) to 1.0 (High)
         double close_pos = 0.5;
         if(total_range > 0)
            close_pos = (mid_c[idx_cl_mid] - mid_l[idx_cl_mid]) / total_range;

         if(close_pos > 0.66)
            data.absorption = "BULL_ABS"; // Closing High = Demand absorbed Supply
         else
            if(close_pos < 0.33)
               data.absorption = "BEAR_ABS"; // Closing Low = Supply absorbed Demand
            else
               data.absorption = "NEUT_ABS"; // Doji-like struggle
        }
      else
         if(bar_rvol > 3.5 && body < (0.6 * mid_atr))
           {
            // Volume Climax: Excessive volume with moderate move implies churn/exhaustion
            data.absorption = "CLIMAX";
           }
     }
   else
     {
      data.absorption = "-";
     }

// MTF Align (Based on TSI Histogram Direction)
// + Hist = Bull pressure, - Hist = Bear pressure
   bool h1_bull = (data.h1_tsi_hist > 0);
   bool m15_bull = (data.m15_tsi_hist > 0);
   bool m5_bull = (data.m5_tsi_hist > 0);

   if(h1_bull == m15_bull && m15_bull == m5_bull)
      data.mtf_align = "FULL_" + (h1_bull ? "BULL" : "BEAR");
   else
      if(h1_bull == m15_bull)
         data.mtf_align = "MAJOR_" + (h1_bull ? "BULL" : "BEAR");
      else
         data.mtf_align = "MIXED";

   return true;
  }

//+------------------------------------------------------------------+
//| WRAPPERS (Helpers) - NEW ONES INCLUDED                           |
//+------------------------------------------------------------------+
bool FetchData(string sym, ENUM_TIMEFRAMES tf, int count, datetime &t[], double &o[], double &h[], double &l[], double &c[], long &v[])
  {
   if(!CDataSync::EnsureDataReady(sym, tf, count))
      return false;
   ArraySetAsSeries(t, false);
   ArraySetAsSeries(o, false);
   ArraySetAsSeries(h, false);
   ArraySetAsSeries(l, false);
   ArraySetAsSeries(c, false);
   ArraySetAsSeries(v, false);
   if(CopyTime(sym, tf, 0, count, t)!=count || CopyOpen(sym, tf, 0, count, o)!=count ||
      CopyHigh(sym, tf, 0, count, h)!=count || CopyLow(sym, tf, 0, count, l)!=count ||
      CopyClose(sym, tf, 0, count, c)!=count || CopyTickVolume(sym, tf, 0, count, v)!=count)
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Calc_ATR(const double &o[], const double &h[], const double &l[], const double &c[], int p, int idx)
  {
   CATRCalculator calc;
   if(!calc.Init(p, ATR_POINTS))
      return 0;
   double buf[];
   int total=ArraySize(c);
   calc.Calculate(total, 0, o, h, l, c, buf);
   return buf[idx];
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Calc_RVOL(const long &vol[], int p, int idx)
  {
   CRelativeVolumeCalculator calc;
   calc.Init(p);
   return calc.CalculateSingle(ArraySize(vol), vol, idx);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Calc_Velocity(const double &close[], double atr, int period, int idx)
  {
   if(atr == 0)
      return 0;
   int total = ArraySize(close);
// We measure displacement from [idx - period] to [idx]
   if(idx < period)
      return 0;
   return CMetricsTools::CalculateSlope(close[idx], close[idx-period], atr, period);
  }

//+------------------------------------------------------------------+
//| WRAPPER: Squeeze                                                 |
//+------------------------------------------------------------------+
void Calc_Squeeze_Full(string sym, ENUM_TIMEFRAMES tf, const double &o[], const double &h[], const double &l[], const double &c[], int idx, string &state, double &mom_val)
  {
   int total = ArraySize(c);
   CSqueezeCalculator sqz;
   if(!sqz.Init(InpSqueezeLength, InpBBMult, InpKCMult, 12))
     {
      state="ERR";
      mom_val=0;
      return;
     }

   double mom[], val[], col[];
   ArrayResize(mom, total);
   ArrayResize(val, total);
   ArrayResize(col, total);

   sqz.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, mom, val, col);

   if(idx < total)
     {
      state   = (col[idx] == 1.0) ? "ON" : "OFF";
      mom_val = mom[idx];
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string Calc_MurreyZone(string symbol, ENUM_TIMEFRAMES tf)
  {
   CMurreyMathCalculator calc;
   calc.Init(symbol, tf, InpMurreyPeriod, 0);
   double levels[];
   if(!calc.Calculate(levels))
      return "N/A";
   double price = iClose(symbol, tf, 0); // Always Live Price
   if(price < levels[2])
      return "Extreme Low";
   if(price > levels[10])
      return "Extreme High";
   if(price >= levels[2] && price < levels[3])
      return "0/8-1/8 (Bottom)";
   if(price >= levels[3] && price < levels[4])
      return "1/8-2/8 (Weak)";
   if(price >= levels[4] && price < levels[6])
      return "2/8-4/8 (Lower)";
   if(price >= levels[6] && price < levels[8])
      return "4/8-6/8 (Upper)";
   if(price >= levels[8] && price < levels[9])
      return "6/8-7/8 (Weak)";
   return "7/8-8/8 (Top)";
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Calc_TSI_Values(const double &o[], const double &h[], const double &l[], const double &c[], int idx, double &val, double &hist)
  {
   CTSICalculator calc;
   calc.Init(InpTSI_Slow, EMA, InpTSI_Fast, EMA, InpTSI_Signal, EMA);
   double tsi[], sig[], osc[];
   int total=ArraySize(c);
   ArrayResize(tsi, total);
   ArrayResize(sig, total);
   ArrayResize(osc, total);
   calc.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, tsi, sig, osc);
   if(idx < total)
     {
      val = tsi[idx];
      hist = tsi[idx] - sig[idx];
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Calc_VHF(const double &o[], const double &h[], const double &l[], const double &c[], int p, int idx)
  {
   CVHFCalculator calc;
   calc.Init(p, VHF_MODE_HIGH_LOW); // Using High-Low mode for Pro
   double buf[];
   int total = ArraySize(c);
   ArrayResize(buf, total);
// VHF Calc expects OHLC if using HighLow mode
   calc.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, buf);
   return buf[idx];
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Calc_R2(const double &o[], const double &h[], const double &l[], const double &c[], int p, int idx)
  {
   CLinearRegressionCalculator calc;
   calc.Init(p);
   double s[], r2[], f[];
   int total = ArraySize(c);
   ArrayResize(s, total);
   ArrayResize(r2, total);
   ArrayResize(f, total);

// FIX: Pass explicit arrays for all OHLC positions
   calc.CalculateState(total, 0, o, h, l, c, PRICE_CLOSE, s, r2, f);

   return r2[idx];
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Calc_VScore(string sym, const datetime &t[], const double &o[], const double &h[], const double &l[], const double &c[], const long &v[], int p, int idx)
  {
   CVScoreCalculator calc;
   calc.Init(p, PERIOD_SESSION);
   double buf[];
   int total = ArraySize(c);
   ArrayResize(buf, total);
   calc.Calculate(total, 0, t, o, h, l, c, v, v, buf);
   return buf[idx];
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Calc_AutoCorr(const double &o[], const double &h[], const double &l[], const double &c[], int p, int idx)
  {
   CAutocorrelationCalculator calc;
   calc.Init(p);
   double buf[];
   int total = ArraySize(c);
   ArrayResize(buf, total);
   calc.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, buf);
   return buf[idx];
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
