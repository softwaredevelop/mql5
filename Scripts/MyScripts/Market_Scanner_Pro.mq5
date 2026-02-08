//+------------------------------------------------------------------+
//|                                           Market_Scanner_Pro.mq5 |
//|                    QuantScan 6.0 - Full Feature Set              |
//|                    Copyright 2026, xxxxxxxx                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "6.00" // Full: Slope, Cost, Session, MTF Align
#property description "Exports 'QuantScan 6.0' dataset for LLM Analysis."
#property description "Complete toolset: Context, Flow, Trigger, Metrics."
#property script_show_inputs

//--- Include Custom Calculators
#include <MyIncludes\DSMA_Calculator.mqh>
#include <MyIncludes\VWAP_Calculator.mqh>
#include <MyIncludes\Laguerre_RSI_Calculator.mqh>
#include <MyIncludes\TSI_Calculator.mqh>
#include <MyIncludes\MurreyMath_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\Bollinger_Bands_Calculator.mqh>
#include <MyIncludes\KeltnerChannel_Calculator.mqh>
#include <MyIncludes\MathStatistics_Calculator.mqh>
#include <MyIncludes\ZScore_Calculator.mqh>
#include <MyIncludes\EfficiencyRatio_Calculator.mqh>
#include <MyIncludes\RelativeVolume_Calculator.mqh>
#include <MyIncludes\SessionLevels_Calculator.mqh>
#include <MyIncludes\Metrics_Tools.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "Scanner Config"
input bool     InpUseMarketWatch = false;    // Scan all Market Watch symbols
input string   InpSymbolList     = "EURUSD,USDJPY,GBPUSD,USDCHF,AUDUSD,XAUUSD,US500,DE40,XTIUSD,ETHUSD";
input string   InpBenchmark      = "US500";  // Global Benchmark
input string   InpForexBench     = "DX";     // Forex Benchmark
input string   InpBrokerTimeZone = "EET (UTC+2)";
input int      InpScanHistory    = 500;      // Max History Bars to fetch

input group "Benchmark Settings"
input int      InpBetaLookback   = 60;       // Beta Calculation Period

input group "Timeframes"
input ENUM_TIMEFRAMES InpTFFast  = PERIOD_M5;  // Layer 3 (Trigger)
input ENUM_TIMEFRAMES InpTFMiddle= PERIOD_M15; // Layer 2 (Flow)
input ENUM_TIMEFRAMES InpTFSlow  = PERIOD_H1;  // Layer 1 (Context)

input group "Metric Settings"
input int      InpDSMAPeriod     = 40;
input double   InpLaguerreGamma  = 0.50;
input int      InpMurreyPeriod   = 64;
input int      InpATRPeriod      = 14;
input int      InpRSBars         = 24;   // Relative Strength Lookback
input int      InpRVOLPeriod     = 20;   // Relative Volume Lookback
input int      InpERPeriod       = 10;   // Efficiency Ratio Lookback
input int      InpZScorePeriod   = 20;   // Z-Score Lookback
input int      InpSlopeLookback  = 5;    // Bars back for Slope calculation

input group "TSI Settings"
input int      InpTSI_Slow       = 25;
input int      InpTSI_Fast       = 13;
input int      InpTSI_Signal     = 13;

input group "Squeeze Settings"
input int      InpSqueezeLength  = 20;
input double   InpBBMult         = 2.0;
input double   InpKCMult         = 1.5;

//--- Struct for QuantScan Data
struct QuantData
  {
   string            timestamp;
   string            symbol;
   double            price;

   // --- Layer 1: H1 Context ---
   double            trend_score;
   double            trend_qual;
   double            trend_slope;
   string            zone;
   double            dist_pdh;         // Dist to Prev High
   double            dist_pdl;         // Dist to Prev Low
   string            rel_strength_str;
   string            beta_str;
   string            alpha_str;
   string            h1_tsi_dir;

   // --- Layer 2: M15 Flow ---
   double            m15_momentum;
   double            m15_vol_qual;
   string            m15_squeeze;
   double            m15_vwap_slope;
   double            m15_z_score;
   double            m15_vola_regime;
   string            m15_tsi_dir;
   double            spread_cost;

   // --- Layer 3: M5 Trigger ---
   double            m5_momentum;
   double            m5_vol_qual;
   string            m5_tsi_dir;
   double            m5_velocity;

   // --- Composites ---
   double            rev_prob;
   string            absorption;
   string            mtf_align;
  };

//+------------------------------------------------------------------+
//| Helper: Detect Asset Class                                       |
//+------------------------------------------------------------------+
bool IsForexPair(string sym)
  {
   if(sym == InpBenchmark || sym == InpForexBench)
      return false;
   if(StringFind(sym, "USD") != -1 || StringFind(sym, "EUR") != -1 ||
      StringFind(sym, "JPY") != -1 || StringFind(sym, "CHF") != -1 ||
      StringFind(sym, "AUD") != -1 || StringFind(sym, "CAD") != -1 || StringFind(sym, "NZD") != -1)
     {
      if(StringFind(sym, "XAU")!=-1 || StringFind(sym, "XTI")!=-1 || StringFind(sym, "WTI")!=-1 || StringFind(sym, "BTC")!=-1 || StringFind(sym, "ETH")!=-1)
         return false;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Helper: Get Sentiment String for TF                              |
//+------------------------------------------------------------------+
string GetSentimentForTF(ENUM_TIMEFRAMES tf)
  {
   double u_close[2], d_close[2];
   if(CopyClose(InpBenchmark, tf, 1, 2, u_close) != 2)
      return "N/A";
   if(CopyClose(InpForexBench, tf, 1, 2, d_close) != 2)
      return "N/A";

   double us500_chg = (u_close[1] - u_close[0]);
   double dxy_chg   = (d_close[1] - d_close[0]);

   double us500_pct = (u_close[0]!=0) ? (us500_chg / u_close[0])*100 : 0;
   double dxy_pct   = (d_close[0]!=0) ? (dxy_chg / d_close[0])*100 : 0;

   string state = "MIXED";
   if(dxy_chg < 0 && us500_chg > 0)
      state = "RISK-ON";
   else
      if(dxy_chg > 0 && us500_chg < 0)
         state = "RISK-OFF";
      else
         if(dxy_chg > 0 && us500_chg > 0)
            state = "STRESS";
         else
            if(dxy_chg < 0 && us500_chg < 0)
               state = "DEFLATION";

   string tf_name = EnumToString(tf);
   StringReplace(tf_name, "PERIOD_", "");
   return StringFormat("%s: %s (US:%.2f%% DX:%.2f%%)", tf_name, state, us500_pct, dxy_pct);
  }

//+------------------------------------------------------------------+
//| WRAPPER DECLARATIONS (Forward Declaration not strictly needed)   |
//+------------------------------------------------------------------+
bool FetchData(string sym, ENUM_TIMEFRAMES tf, int count, datetime &t[], double &o[], double &h[], double &l[], double &c[], long &v[]);
double Calc_ATR(const double &o[], const double &h[], const double &l[], const double &c[], int p);
double Calc_ER(const double &o[], const double &h[], const double &l[], const double &c[], int p);
double Calc_ZScore(const double &o[], const double &h[], const double &l[], const double &c[], int p);
double Calc_RVOL(const long &vol[], int p);
double Calc_DSMA_Score(const double &o[], const double &h[], const double &l[], const double &c[], double atr);
string Calc_Squeeze(string sym, ENUM_TIMEFRAMES tf, const double &o[], const double &h[], const double &l[], const double &c[]);
double Calc_LaguerreRSI(const double &o[], const double &h[], const double &l[], const double &c[]);
void Calc_TSI_Dir(const double &o[], const double &h[], const double &l[], const double &c[], string &dir);
string Calc_MurreyZone(string symbol, ENUM_TIMEFRAMES tf);
void Calc_DSMA_Series(const double &o[], const double &h[], const double &l[], const double &c[], double &out_buf[]);
void Calc_VWAP_Series(const datetime &t[], const double &o[], const double &h[], const double &l[], const double &c[], const long &v[], ENUM_VWAP_PERIOD p, double &out_buf[]);
double Calc_Velocity(const double &close[], double atr, int period);
double Calc_RVOL_Single_Help(const long &vol[], int period, int index); // Helper proxy

//+------------------------------------------------------------------+
//| Script Start                                                     |
//+------------------------------------------------------------------+
void OnStart()
  {
   string symbols[];
   int total_symbols = 0;

// 1. Symbol List Compilation
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

// 2. Global Sentiment (Prices)
   double bench_change_pct = 0.0;
   bool has_us500 = SymbolSelect(InpBenchmark, true);
   bool has_dxy   = SymbolSelect(InpForexBench, true);

   if(has_us500)
     {
      double b_close[], b_open[];
      if(CopyClose(InpBenchmark, InpTFSlow, 1, 1, b_close) > 0 && CopyOpen(InpBenchmark, InpTFSlow, InpRSBars, 1, b_open) > 0)
         if(b_open[0] != 0)
            bench_change_pct = ((b_close[0] - b_open[0]) / b_open[0]) * 100.0;
     }

   string filename = "QuantScan_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + ".csv";
   StringReplace(filename, ":", "");
   StringReplace(filename, " ", "_");

   int file_handle = FileOpen(filename, FILE_CSV|FILE_WRITE|FILE_ANSI, ";");
   if(file_handle == INVALID_HANDLE)
      return;

// 3. SCAN & STORE (Phase 1)
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

      if(RunQuantAnalysis(sym, bench_change_pct, temp_data))
        {
         ArrayResize(results, success_count + 1);
         results[success_count] = temp_data;
         success_count++;
        }
      else
        {
         Print("Scan Failed: ", sym);
        }
     }

// 4. BREADTH CALCULATION (Phase 2)
   int tsi_bull_count = 0;
   int vel_pos_count  = 0;
   int mtf_full_count = 0;

   for(int i=0; i<success_count; i++)
     {
      if(results[i].m15_tsi_dir == "BULL")
         tsi_bull_count++;
      if(results[i].m5_velocity > 0)
         vel_pos_count++;
      if(StringFind(results[i].mtf_align, "FULL_") != -1)
         mtf_full_count++;
     }

   double breadth_tsi = (success_count>0) ? ((double)tsi_bull_count/success_count)*100.0 : 0;
   double breadth_vel = (success_count>0) ? ((double)vel_pos_count/success_count)*100.0 : 0;

   string sentiment_line = "### GLOBAL_SENTIMENT | ";
   if(has_us500 && has_dxy)
     {
      sentiment_line += GetSentimentForTF(InpTFSlow) + " | " + GetSentimentForTF(InpTFMiddle) + " | " + GetSentimentForTF(InpTFFast);
     }
   else
      sentiment_line += "Benchmarks Missing";

// Append Breadth Score to Header Line 1
   sentiment_line += StringFormat(" ### BREADTH_SCORE | TSI_BULL: %d/%d (%.0f%%) | VEL_POS: %d/%d (%.0f%%) | MTF_ALIGN: %d ###",
                                  tsi_bull_count, success_count, breadth_tsi, vel_pos_count, success_count, breadth_vel, mtf_full_count);

// 5. WRITE TO FILE (Phase 3)
   FileWrite(file_handle, sentiment_line);

// Header Row
   string str_slow = EnumToString(InpTFSlow);
   StringReplace(str_slow, "PERIOD_", "");
   string str_mid  = EnumToString(InpTFMiddle);
   StringReplace(str_mid, "PERIOD_", "");
   string str_fast = EnumToString(InpTFFast);
   StringReplace(str_fast, "PERIOD_", "");

   string csv_header = "TIME (" + InpBrokerTimeZone + ");SYMBOL;PRICE;";
   csv_header += StringFormat("TREND_SC_%s;TREND_QUAL_%s;TREND_SLOPE_%s;ZONE_%s;DIST_PDH_%s;DIST_PDL_%s;REL_STR_%s;BETA_%s;ALPHA_%s;",str_slow, str_slow, str_slow, str_slow, str_slow, str_slow, str_slow, str_slow, str_slow);
   csv_header += StringFormat("MOM_%s;RVOL_%s;SQZ_%s;VWAP_SLOPE_%s;Z_SCORE_%s;VOL_REGIME_%s;COST_ATR_%s;TSI_DIR_%s;",str_mid, str_mid, str_mid, str_mid, str_mid, str_mid, str_mid, str_mid);
   csv_header += StringFormat("MOM_%s;RVOL_%s;TSI_DIR_%s;VEL_%s;", str_fast, str_fast, str_fast, str_fast);
   csv_header += "REV_PROB;ABSORPTION;MTF_ALIGN";

   FileWrite(file_handle, csv_header);

   for(int i=0; i<success_count; i++)
     {
      FileWrite(file_handle,
                results[i].timestamp,
                results[i].symbol,
                DoubleToString(results[i].price, (int)SymbolInfoInteger(results[i].symbol, SYMBOL_DIGITS)),
                // Layer 1
                DoubleToString(results[i].trend_score, 2),
                DoubleToString(results[i].trend_qual, 2),
                DoubleToString(results[i].trend_slope, 2),
                results[i].zone,
                DoubleToString(results[i].dist_pdh, 2),
                DoubleToString(results[i].dist_pdl, 2),
                results[i].rel_strength_str,
                results[i].beta_str,
                results[i].alpha_str,
                // Layer 2
                DoubleToString(results[i].m15_momentum, 2),
                DoubleToString(results[i].m15_vol_qual, 2),
                results[i].m15_squeeze,
                DoubleToString(results[i].m15_vwap_slope, 2),
                DoubleToString(results[i].m15_z_score, 2),
                DoubleToString(results[i].m15_vola_regime, 2),
                DoubleToString(results[i].spread_cost, 2),
                results[i].m15_tsi_dir,
                // Layer 3
                DoubleToString(results[i].m5_momentum, 2),
                DoubleToString(results[i].m5_vol_qual, 2),
                results[i].m5_tsi_dir,
                DoubleToString(results[i].m5_velocity, 2),
                // Composites
                DoubleToString(results[i].rev_prob, 0) + "%",
                results[i].absorption,
                results[i].mtf_align
               );
     }

   FileClose(file_handle);
   Print("Done. Analyzed ", success_count, " symbols. File saved to MQL5/Files/", filename);
  }

//+------------------------------------------------------------------+
//| Core Logic: Run Quant Analysis                                   |
//+------------------------------------------------------------------+
bool RunQuantAnalysis(string sym, double bench_change, QuantData &data)
  {
   data.timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
   StringReplace(data.timestamp, ".", ".");
   data.symbol    = sym;
   data.price     = SymbolInfoDouble(sym, SYMBOL_BID);

// =================================================================
// LAYER 1: CONTEXT (H1)
// =================================================================
   double slow_o[], slow_h[], slow_l[], slow_c[];
   long slow_v[];
   datetime slow_t[];
   if(!FetchData(sym, InpTFSlow, InpScanHistory, slow_t, slow_o, slow_h, slow_l, slow_c, slow_v))
      return false;

   double slow_atr = Calc_ATR(slow_o, slow_h, slow_l, slow_c, InpATRPeriod);
   if(slow_atr == 0)
      return false;

// DSMA & Slope
   double dsma_series[];
   Calc_DSMA_Series(slow_o, slow_h, slow_l, slow_c, dsma_series);
   int idx_s = ArraySize(slow_c) - 2;
   data.trend_score = (slow_atr!=0) ? (slow_c[idx_s] - dsma_series[idx_s]) / slow_atr : 0;
   data.trend_slope = CMetricsTools::CalculateSlope(dsma_series[idx_s], dsma_series[idx_s - InpSlopeLookback], slow_atr, InpSlopeLookback);

   data.trend_qual  = Calc_ER(slow_o, slow_h, slow_l, slow_c, InpERPeriod);
   data.zone        = Calc_MurreyZone(sym, InpTFSlow);

// Session Distances
   CSessionLevelsCalculator sess_calc;
   if(sess_calc.Init(PERIOD_D1))
     {
      SessionLevels sl;

      if(sess_calc.GetLevels(sym, slow_t[idx_s], sl))
        {
         data.dist_pdh = CMetricsTools::CalculateDistance(slow_c[idx_s], sl.prev_high, slow_atr);
         data.dist_pdl = CMetricsTools::CalculateDistance(slow_c[idx_s], sl.prev_low, slow_atr);
        }
     }

   Calc_TSI_Dir(slow_o, slow_h, slow_l, slow_c, data.h1_tsi_dir); // For MTF

// Beta/Alpha
   bool is_benchmark = (sym == InpBenchmark || sym == InpForexBench);
   if(is_benchmark)
     {
      data.rel_strength_str="BENCH";
      data.beta_str="1.0";
      data.alpha_str="0.0";
     }
   else
     {
      string bench_sym = InpBenchmark;
      if(IsForexPair(sym) && SymbolSelect(InpForexBench, true))
         bench_sym = InpForexBench;

      double bench_c[];
      if(CopyClose(bench_sym, InpTFSlow, 0, InpBetaLookback+2, bench_c) > InpBetaLookback)
        {
         CMathStatisticsCalculator stats;
         double asset_ret[], bench_ret[];

         int h1_size = ArraySize(slow_c);
         double asset_subset[];
         ArrayResize(asset_subset, InpBetaLookback);
         double bench_subset[];
         ArrayResize(bench_subset, InpBetaLookback);

         for(int k=0; k<InpBetaLookback; k++)
           {
            asset_subset[k] = slow_c[h1_size - InpBetaLookback + k];
            bench_subset[k] = bench_c[ArraySize(bench_c) - InpBetaLookback + k];
           }

         stats.ComputeReturns(asset_subset, asset_ret);
         stats.ComputeReturns(bench_subset, bench_ret);

         double beta_val = stats.CalculateBeta(asset_ret, bench_ret);
         double a_tot = (asset_subset[InpBetaLookback-1] - asset_subset[0]) / asset_subset[0];
         double b_tot = (bench_subset[InpBetaLookback-1] - bench_subset[0]) / bench_subset[0];
         double alpha_val = stats.CalculateAlpha(a_tot, b_tot, beta_val);
         double rel_val = (a_tot - b_tot) * 100.0; // Raw difference usually

         data.rel_strength_str = DoubleToString(rel_val, 2) + "%";
         data.beta_str         = DoubleToString(beta_val, 2);
         data.alpha_str        = DoubleToString(alpha_val, 4);
        }
      else
        {
         data.rel_strength_str = "0%";
         data.beta_str = "0";
         data.alpha_str = "0";
        }
     }

// =================================================================
// LAYER 2: FLOW (M15)
// =================================================================
   double mid_o[], mid_h[], mid_l[], mid_c[];
   long mid_v[];
   datetime mid_t[];
   if(!FetchData(sym, InpTFMiddle, InpScanHistory, mid_t, mid_o, mid_h, mid_l, mid_c, mid_v))
      return false;

   double mid_atr = Calc_ATR(mid_o, mid_h, mid_l, mid_c, InpATRPeriod);

   data.m15_momentum = Calc_LaguerreRSI(mid_o, mid_h, mid_l, mid_c);
   data.m15_vol_qual = Calc_RVOL(mid_v, InpRVOLPeriod);
   data.m15_squeeze  = Calc_Squeeze(sym, InpTFMiddle, mid_o, mid_h, mid_l, mid_c);
   data.m15_z_score  = Calc_ZScore(mid_o, mid_h, mid_l, mid_c, InpZScorePeriod);

// VWAP Slope
   double vwap_series[];
   Calc_VWAP_Series(mid_t, mid_o, mid_h, mid_l, mid_c, mid_v, PERIOD_SESSION, vwap_series);
   int idx_m = ArraySize(mid_c) - 2;
   data.m15_vwap_slope = CMetricsTools::CalculateSlope(vwap_series[idx_m], vwap_series[idx_m - InpSlopeLookback], mid_atr, InpSlopeLookback);

// Cost
   data.spread_cost = CMetricsTools::CalculateSpreadCost(sym, mid_atr);

   double atr_f = Calc_ATR(mid_o, mid_h, mid_l, mid_c, 5);
   double atr_s = Calc_ATR(mid_o, mid_h, mid_l, mid_c, 50);
   data.m15_vola_regime = (atr_s!=0) ? atr_f/atr_s : 1.0;

   Calc_TSI_Dir(mid_o, mid_h, mid_l, mid_c, data.m15_tsi_dir);

// =================================================================
// LAYER 3: TRIGGER (M5)
// =================================================================
   double fast_o[], fast_h[], fast_l[], fast_c[];
   long fast_v[];
   datetime fast_t[];
   if(!FetchData(sym, InpTFFast, 300, fast_t, fast_o, fast_h, fast_l, fast_c, fast_v))
      return false;

   double fast_atr = Calc_ATR(fast_o, fast_h, fast_l, fast_c, InpATRPeriod);

   data.m5_momentum = Calc_LaguerreRSI(fast_o, fast_h, fast_l, fast_c);
   data.m5_vol_qual = Calc_RVOL(fast_v, InpRVOLPeriod);
   Calc_TSI_Dir(fast_o, fast_h, fast_l, fast_c, data.m5_tsi_dir);
   data.m5_velocity = Calc_Velocity(fast_c, fast_atr, 3);

// =================================================================
// COMPOSITES
// =================================================================
   double score = 0;
   if(MathAbs(data.m15_z_score) > 3.0)
      score += 40;
   else
      if(MathAbs(data.m15_z_score) > 2.0)
         score += 20;
   if(StringFind(data.zone, "Extreme") >= 0)
      score += 30;
   if(data.m15_momentum > 0.90 || data.m15_momentum < 0.10)
      score += 30;
   data.rev_prob = score;

   int idx_cl = ArraySize(mid_c) - 2;
   if(idx_cl >= 0 && mid_atr > 0)
     {
      double body = MathAbs(mid_c[idx_cl] - mid_o[idx_cl]);
      double bar_rvol = Calc_RVOL_Single_Help(mid_v, InpRVOLPeriod, idx_cl);
      if(bar_rvol > 2.0 && body < (0.4 * mid_atr))
         data.absorption = "YES";
      else
         data.absorption = "NO";
     }
   else
      data.absorption = "-";

// MTF Align
   if(data.h1_tsi_dir == data.m15_tsi_dir && data.m15_tsi_dir == data.m5_tsi_dir)
      data.mtf_align = "FULL_" + data.h1_tsi_dir;
   else
      if(data.h1_tsi_dir == data.m15_tsi_dir)
         data.mtf_align = "MAJOR_" + data.h1_tsi_dir;
      else
         data.mtf_align = "MIXED";

   return true;
  }

//+------------------------------------------------------------------+
//| WRAPPER FUNCTIONS (IMPLEMENTATION)                               |
//+------------------------------------------------------------------+
// Updated FetchData with Sync Logic
bool FetchData(string sym, ENUM_TIMEFRAMES tf, int count, datetime &t[], double &o[], double &h[], double &l[], double &c[], long &v[])
  {
// 1. Force Sync first
   if(!CDataSync::EnsureDataReady(sym, tf, count))
      return false;

   ArraySetAsSeries(t, false);
   ArraySetAsSeries(o, false);
   ArraySetAsSeries(h, false);
   ArraySetAsSeries(l, false);
   ArraySetAsSeries(c, false);
   ArraySetAsSeries(v, false);

// Now Copy should work reliably
   if(CopyTime(sym, tf, 0, count, t)!=count || CopyOpen(sym, tf, 0, count, o)!=count ||
      CopyHigh(sym, tf, 0, count, h)!=count || CopyLow(sym, tf, 0, count, l)!=count ||
      CopyClose(sym, tf, 0, count, c)!=count || CopyTickVolume(sym, tf, 0, count, v)!=count)
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Calc_DSMA_Series(const double &o[], const double &h[], const double &l[], const double &c[], double &out_buf[])
  {
   CDSMACalculator calc;
   if(!calc.Init(InpDSMAPeriod))
      return;
   int total=ArraySize(c);
   ArrayResize(out_buf, total);
   calc.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, out_buf);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Calc_VWAP_Series(const datetime &t[], const double &o[], const double &h[], const double &l[], const double &c[], const long &v[], ENUM_VWAP_PERIOD p, double &out_buf[])
  {
   CVWAPCalculator calc;
   if(!calc.Init(p, VOLUME_TICK, 0, true))
      return;
   double odd[], even[];
   int total=ArraySize(c);
   ArrayResize(odd, total);
   ArrayResize(even, total);
   calc.Calculate(total, 0, t, o, h, l, c, v, v, odd, even);
   ArrayResize(out_buf, total);
   for(int i=0; i<total; i++)
      out_buf[i] = (odd[i]!=EMPTY_VALUE && odd[i]!=0) ? odd[i] : even[i];
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Calc_RVOL_Single_Help(const long &vol[], int period, int index)
  {
   CRelativeVolumeCalculator calc;
   calc.Init(period);
   return calc.CalculateSingle(ArraySize(vol), vol, index);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Calc_Velocity(const double &close[], double atr, int period)
  {
   if(atr == 0)
      return 0;
   int total = ArraySize(close);
   if(total <= period+2)
      return 0;
   double sum_move = 0;
   for(int i=0; i<period; i++)
      sum_move += MathAbs(close[total-2-i] - close[total-3-i]);
   return (sum_move / period) / atr;
  }

// Reuse Short Wrappers
double Calc_ATR(const double &o[], const double &h[], const double &l[], const double &c[], int p)
  {
   CATRCalculator calc;
   if(!calc.Init(p, ATR_POINTS))
      return 0;
   double buf[];
   int total=ArraySize(c);
   calc.Calculate(total, 0, o, h, l, c, buf);
   return buf[total-2];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Calc_ER(const double &o[], const double &h[], const double &l[], const double &c[], int p)
  {
   CEfficiencyRatioCalculator calc;
   if(!calc.Init(p))
      return 0;
   double buf[];
   int total=ArraySize(c);
   ArrayResize(buf, total);
   calc.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, buf);
   return buf[total-2];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Calc_ZScore(const double &o[], const double &h[], const double &l[], const double &c[], int p)
  {
   CZScoreCalculator calc;
   if(!calc.Init(p))
      return 0;
   double buf[];
   int total=ArraySize(c);
   ArrayResize(buf, total);
   calc.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, buf);
   return buf[total-2];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Calc_RVOL(const long &vol[], int p)
  {
   CRelativeVolumeCalculator calc;
   calc.Init(p);
   return calc.CalculateSingle(ArraySize(vol), vol, ArraySize(vol)-2);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Calc_DSMA_Score(const double &o[], const double &h[], const double &l[], const double &c[], double atr)
  {
   CDSMACalculator calc;
   if(!calc.Init(InpDSMAPeriod))
      return 0;
   double buf[];
   int total=ArraySize(c);
   ArrayResize(buf, total);
   calc.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, buf);
   if(atr==0)
      return 0;
   return (c[total-2] - buf[total-2]) / atr;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string Calc_Squeeze(string sym, ENUM_TIMEFRAMES tf, const double &o[], const double &h[], const double &l[], const double &c[])
  {
   int total = ArraySize(c);
   CBollingerBandsCalculator bb;
   bb.Init(InpSqueezeLength, InpBBMult, SMA);
   CKeltnerChannelCalculator kc;
   kc.Init(InpSqueezeLength, SMA, InpSqueezeLength, InpKCMult, ATR_SOURCE_STANDARD);
   double b_ma[], b_up[], b_lo[];
   ArrayResize(b_ma, total);
   ArrayResize(b_up, total);
   ArrayResize(b_lo, total);
   double k_ma[], k_up[], k_lo[];
   ArrayResize(k_ma, total);
   ArrayResize(k_up, total);
   ArrayResize(k_lo, total);
   bb.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, b_ma, b_up, b_lo);
   kc.Calculate(total, 0, o, h, l, c, PRICE_CLOSE, k_ma, k_up, k_lo);
   int idx = total - 2;
   return ((b_up[idx] < k_up[idx]) && (b_lo[idx] > k_lo[idx])) ? "ON" : "OFF";
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Calc_LaguerreRSI(const double &o[], const double &h[], const double &l[], const double &c[])
  {
   CLaguerreRSICalculator calc;
   calc.Init(InpLaguerreGamma, 3, SMA);
   double lrsi[], sig[];
   int total=ArraySize(c);
   ArrayResize(lrsi, total);
   ArrayResize(sig, total);
   calc.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, lrsi, sig);
   return lrsi[total-2] / 100.0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Calc_TSI_Dir(const double &o[], const double &h[], const double &l[], const double &c[], string &dir)
  {
   CTSICalculator calc;
   calc.Init(InpTSI_Slow, EMA, InpTSI_Fast, EMA, InpTSI_Signal, EMA);
   double tsi[], sig[], osc[];
   int total=ArraySize(c);
   ArrayResize(tsi, total);
   ArrayResize(sig, total);
   ArrayResize(osc, total);
   calc.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, tsi, sig, osc);
   if(tsi[total-2] > sig[total-2])
      dir = "BULL";
   else
      dir = "BEAR";
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
   double price = iClose(symbol, tf, 1);
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
//+------------------------------------------------------------------+
