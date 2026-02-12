//+------------------------------------------------------------------+
//|                                           Market_Scanner_Pro.mq5 |
//|                    QuantScan 8.3 - Squeeze Momentum              |
//|                    Copyright 2026, xxxxxxxx                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "8.30" // Updated with Sync Fix
#property description "Exports 'QuantScan 8.0' dataset for LLM Analysis."
#property description "Now includes Squeeze Momentum direction/value."
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
// NEW INCLUDE
#include <MyIncludes\Squeeze_Calculator.mqh>

//--- Input Parameters ---
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
input int      InpDSMAPeriod     = 40;
input double   InpLaguerreGamma  = 0.50;
input int      InpMurreyPeriod   = 64;
input int      InpATRPeriod      = 14;
input int      InpRSBars         = 24;
input int      InpRVOLPeriod     = 20;
input int      InpERPeriod       = 10;
input int      InpZScorePeriod   = 20;
input int      InpSlopeLookback  = 5;

input group "TSI Settings"
input int      InpTSI_Slow       = 25;
input int      InpTSI_Fast       = 13;
input int      InpTSI_Signal     = 13;

input group "Squeeze Settings"
input int      InpSqueezeLength  = 20;
input double   InpBBMult         = 2.0;
input double   InpKCMult         = 1.5;
input int      InpSqueezeMom     = 12;   // NEW: Squeeze Momentum Period

//--- Struct for QuantScan Data
struct QuantData
  {
   string            timestamp;
   string            symbol;
   double            price;

   // --- Layer 1: H1 Context ---
   double            trend_score;      // Closed
   double            trend_qual;       // Closed
   double            trend_slope;      // Closed
   string            zone;             // Levels Closed, Price Live
   string            rel_strength_str; // Live
   string            beta_str;         // Live
   string            alpha_str;        // Live
   double            h1_tsi_val;       // Live
   double            h1_tsi_hist;      // Live

   // --- Layer 2: M15 Flow (ALL LIVE) ---
   double            dist_pdh;
   double            dist_pdl;
   double            m15_momentum;
   double            m15_vol_qual;
   string            m15_squeeze;
   double            m15_sqz_mom; // NEW: Squeeze Momentum Value
   double            m15_vwap_slope;
   double            m15_z_score;
   double            m15_vola_regime;
   double            m15_tsi_val;
   double            m15_tsi_hist;
   // Cost moved from here

   // --- Layer 3: M5 Trigger (ALL LIVE) ---
   double            m5_momentum;
   double            m5_vol_qual;
   double            m5_tsi_val;
   double            m5_tsi_hist;
   double            m5_velocity;
   double            spread_cost; // MOVED HERE

   // --- Composites ---
   double            vol_thrust;
   double            rev_prob;
   string            absorption;
   string            mtf_align;
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

//--- Helper: Get Sentiment
string GetSentimentForTF(ENUM_TIMEFRAMES tf)
  {
   if(!CDataSync::EnsureDataReady(InpBenchmark, tf, 2))
      return "N/A";
   if(!CDataSync::EnsureDataReady(InpForexBench, tf, 2))
      return "N/A";

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

//--- Wrappers Declarations
bool FetchData(string sym, ENUM_TIMEFRAMES tf, int count, datetime &t[], double &o[], double &h[], double &l[], double &c[], long &v[]);
double Calc_ATR(const double &o[], const double &h[], const double &l[], const double &c[], int p, int idx);
double Calc_ER(const double &o[], const double &h[], const double &l[], const double &c[], int p, int idx);
double Calc_ZScore(const double &o[], const double &h[], const double &l[], const double &c[], int p, int idx);
double Calc_RVOL(const long &vol[], int p, int idx);
double Calc_DSMA_Score(const double &o[], const double &h[], const double &l[], const double &c[], double atr, int idx);
string Calc_Squeeze(string sym, ENUM_TIMEFRAMES tf, const double &o[], const double &h[], const double &l[], const double &c[], int idx);
double Calc_LaguerreRSI(const double &o[], const double &h[], const double &l[], const double &c[], int idx);
void Calc_TSI_Values(const double &o[], const double &h[], const double &l[], const double &c[], int idx, double &val, double &hist);
string Calc_MurreyZone(string symbol, ENUM_TIMEFRAMES tf);
void Calc_DSMA_Series(const double &o[], const double &h[], const double &l[], const double &c[], double &out_buf[]);
void Calc_VWAP_Series(const datetime &t[], const double &o[], const double &h[], const double &l[], const double &c[], const long &v[], ENUM_VWAP_PERIOD p, double &out_buf[]);
double Calc_Velocity(const double &close[], double atr, int period, int idx);


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

// Global Sentiment
   string sentiment_line = "### GLOBAL_SENTIMENT | ";
   bool has_us500 = SymbolSelect(InpBenchmark, true);
   bool has_dxy   = SymbolSelect(InpForexBench, true);
   if(has_us500 && has_dxy)
     {
      sentiment_line += GetSentimentForTF(InpTFSlow) + " | " + GetSentimentForTF(InpTFMiddle) + " | " + GetSentimentForTF(InpTFFast) + " ###";
     }
   else
      sentiment_line += "Benchmarks Missing ###";

   double bench_change_pct = 0.0;
   if(has_us500)
     {
      if(CDataSync::EnsureDataReady(InpBenchmark, InpTFSlow))
        {
         double b_close[], b_open[];
         if(CopyClose(InpBenchmark, InpTFSlow, 1, 1, b_close) > 0 && CopyOpen(InpBenchmark, InpTFSlow, InpRSBars, 1, b_open) > 0)
            if(b_open[0] != 0)
               bench_change_pct = ((b_close[0] - b_open[0]) / b_open[0]) * 100.0;
        }
     }

   string filename = "QuantScan_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + ".csv";
   StringReplace(filename, ":", "");
   StringReplace(filename, " ", "_");

   int file_handle = FileOpen(filename, FILE_CSV|FILE_WRITE|FILE_ANSI, ";");
   if(file_handle == INVALID_HANDLE)
      return;

   FileWrite(file_handle, sentiment_line);

// Header
   string str_slow = EnumToString(InpTFSlow);
   StringReplace(str_slow, "PERIOD_", "");
   string str_mid  = EnumToString(InpTFMiddle);
   StringReplace(str_mid, "PERIOD_", "");
   string str_fast = EnumToString(InpTFFast);
   StringReplace(str_fast, "PERIOD_", "");

   string header = "TIME (" + InpBrokerTimeZone + ");SYMBOL;PRICE;";
   header += StringFormat("TREND_SC_%s;TREND_QUAL_%s;TREND_SLOPE_%s;ZONE_%s;REL_STR_%s;BETA_%s;ALPHA_%s;TSI_VAL_%s;TSI_HIST_%s;",
                          str_slow, str_slow, str_slow, str_slow, str_slow, str_slow, str_slow, str_slow, str_slow);

// M15 Header (Insert SQZ_MOM column next to SQZ)
   header += StringFormat("DIST_PDH_%s;DIST_PDL_%s;MOM_%s;RVOL_%s;SQZ_%s;SQZ_MOM_%s;VWAP_SLOPE_%s;Z_SCORE_%s;VOL_REGIME_%s;TSI_VAL_%s;TSI_HIST_%s;",
                          str_mid, str_mid, str_mid, str_mid, str_mid, str_mid, str_mid, str_mid, str_mid, str_mid, str_mid);

// M5 Header (Added COST_ATR)
   header += StringFormat("MOM_%s;RVOL_%s;TSI_VAL_%s;TSI_HIST_%s;VEL_%s;COST_ATR_%s;", str_fast, str_fast, str_fast, str_fast, str_fast, str_fast);

   header += "VOL_THRUST;REV_PROB;ABSORPTION;MTF_ALIGN";

   FileWrite(file_handle, header);

   PrintFormat("Scanning %d symbols...", total_symbols);

   for(int i=0; i<total_symbols; i++)
     {
      string sym = symbols[i];
      StringTrimLeft(sym);
      StringTrimRight(sym);
      QuantData data;
      ZeroMemory(data);

      if(RunQuantAnalysis(sym, bench_change_pct, data))
        {
         FileWrite(file_handle,
                   data.timestamp,
                   data.symbol,
                   DoubleToString(data.price, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS)),
                   // H1
                   DoubleToString(data.trend_score, 2),
                   DoubleToString(data.trend_qual, 2),
                   DoubleToString(data.trend_slope, 2),
                   data.zone,
                   data.rel_strength_str,
                   data.beta_str,
                   data.alpha_str,
                   DoubleToString(data.h1_tsi_val, 2),
                   DoubleToString(data.h1_tsi_hist, 2),
                   // M15
                   DoubleToString(data.dist_pdh, 2),
                   DoubleToString(data.dist_pdl, 2),
                   DoubleToString(data.m15_momentum, 2),
                   DoubleToString(data.m15_vol_qual, 2),
                   data.m15_squeeze,
                   DoubleToString(data.m15_sqz_mom, 2), // NEW
                   DoubleToString(data.m15_vwap_slope, 2),
                   DoubleToString(data.m15_z_score, 2),
                   DoubleToString(data.m15_vola_regime, 2),
                   // Removed Spread Cost from here in CSV Write order!
                   DoubleToString(data.m15_tsi_val, 2),
                   DoubleToString(data.m15_tsi_hist, 2),
                   // M5
                   DoubleToString(data.m5_momentum, 2),
                   DoubleToString(data.m5_vol_qual, 2),
                   DoubleToString(data.m5_tsi_val, 2),
                   DoubleToString(data.m5_tsi_hist, 2),
                   DoubleToString(data.m5_velocity, 2),
                   DoubleToString(data.spread_cost, 2), // Added Here
                   // Composites
                   DoubleToString(data.vol_thrust, 2),
                   DoubleToString(data.rev_prob, 0) + "%",
                   data.absorption,
                   data.mtf_align
                  );
        }
      else
         Print("Scan Failed (Sync): ", sym);
     }
   FileClose(file_handle);
   Print("Done. File: ", filename);
  }

//+------------------------------------------------------------------+
//| Core Logic (v8.30 Updated with Sync Fix)                         |
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

// Indices
   int idx_live_slow   = ArraySize(slow_c) - 1;
   int idx_closed_slow = ArraySize(slow_c) - 2;

   double slow_atr = Calc_ATR(slow_o, slow_h, slow_l, slow_c, InpATRPeriod, idx_closed_slow);
   if(slow_atr == 0)
      return false;

// Trend Score/Qual/Slope -> CLOSED (Stability)
   double dsma_series[];
   Calc_DSMA_Series(slow_o, slow_h, slow_l, slow_c, dsma_series);
   data.trend_score = (slow_atr!=0) ? (slow_c[idx_closed_slow] - dsma_series[idx_closed_slow]) / slow_atr : 0;
   data.trend_slope = CMetricsTools::CalculateSlope(dsma_series[idx_closed_slow], dsma_series[idx_closed_slow - InpSlopeLookback], slow_atr, InpSlopeLookback);
   data.trend_qual  = Calc_ER(slow_o, slow_h, slow_l, slow_c, InpERPeriod, idx_closed_slow);

// Zone (Murrey) - Calcs on history, Checks against LIVE Price
   data.zone        = Calc_MurreyZone(sym, InpTFSlow);

// TSI -> LIVE
   Calc_TSI_Values(slow_o, slow_h, slow_l, slow_c, idx_live_slow, data.h1_tsi_val, data.h1_tsi_hist);

// --- BETA / ALPHA Calculation (TIME-SYNC FIXED) ---
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

      // Fetch Benchmark Full History (Same depth as asset) to ensure we find matching times
      double b_c[], b_o[], b_h[], b_l[];
      long b_v[];
      datetime b_t[];

      // Force Sync Bench Data first
      if(CDataSync::EnsureDataReady(bench_sym, InpTFSlow, InpScanHistory))
        {
         // Fetch using helper
         if(FetchData(bench_sym, InpTFSlow, InpScanHistory, b_t, b_o, b_h, b_l, b_c, b_v))
           {
            CMathStatisticsCalculator stats;
            int h1_size = ArraySize(slow_c);
            int bench_size = ArraySize(b_c);

            // Allocate subsets
            double asset_subset[];
            ArrayResize(asset_subset, InpBetaLookback);
            double bench_subset[];
            ArrayResize(bench_subset, InpBetaLookback);

            int valid_points = 0;

            // Loop backwards from current LIVE bar [size-1]
            // We fill the subset from End (Newest) to Start (Oldest) to keep chronological order for Returns Calc
            for(int k=0; k<InpBetaLookback; k++)
              {
               // Asset Index
               int a_idx = h1_size - 1 - k;
               if(a_idx < 0)
                  break;

               datetime a_time = slow_t[a_idx];

               // Find Matching Benchmark Index by Time
               // Since arrays are non-series (0=Oldest), we can't use simple math if gaps exist.
               // We use Binary Search (ArrayBsearch) on bench time array
               int b_idx_arr = ArrayBsearch(b_t, a_time);

               // ArrayBsearch returns index. Check if time matches exactly (or close enough)
               if(b_idx_arr >= 0 && b_idx_arr < bench_size && b_t[b_idx_arr] == a_time)
                 {
                  // Match found!
                  int sub_idx = InpBetaLookback - 1 - k; // Fill from end
                  asset_subset[sub_idx] = slow_c[a_idx];
                  bench_subset[sub_idx] = b_c[b_idx_arr];
                  valid_points++;
                 }
               else
                 {
                  // Gap found (e.g. Asset open, Bench closed).
                  // For strict stats, we skip this point or fill with previous?
                  // Skipping creates holes in return calc.
                  // Simple approach: Use previous bench value (Fill forward)?
                  // Better: Simply don't increment valid_points, leave 0? No, stats need continuous series.
                  // Let's copy previous value if match fails (Flat return).
                  int sub_idx = InpBetaLookback - 1 - k;
                  asset_subset[sub_idx] = slow_c[a_idx];
                  // Use prev from subset if k>0? Tricky loop direction.
                  // Simple fallback: Use bench at index approx? No.
                  // If missing, we assume price didnt change from last valid.
                  if(k>0 && sub_idx+1 < InpBetaLookback)
                     bench_subset[sub_idx] = bench_subset[sub_idx+1]; // Prev Loop value (Newer)
                 }
              }

            // Only calc if we have enough synced data
            if(valid_points > InpBetaLookback / 2)
              {
               double asset_ret[], bench_ret[];
               stats.ComputeReturns(asset_subset, asset_ret);
               stats.ComputeReturns(bench_subset, bench_ret);

               double beta_val = stats.CalculateBeta(asset_ret, bench_ret);

               // Period Alpha
               double a_tot = (asset_subset[InpBetaLookback-1] - asset_subset[0]) / asset_subset[0];
               double b_tot = (bench_subset[InpBetaLookback-1] - bench_subset[0]) / bench_subset[0];
               double alpha_val = stats.CalculateAlpha(a_tot, b_tot, beta_val);
               double rel_val = (a_tot - b_tot) * 100.0;

               data.rel_strength_str = DoubleToString(rel_val, 2) + "%";
               data.beta_str         = DoubleToString(beta_val, 2);
               data.alpha_str        = DoubleToString(alpha_val, 4);
              }
            else
              {
               data.rel_strength_str = "-";
               data.beta_str = "0";
               data.alpha_str = "0";
              }
           }
        }
     }

// =================================================================
// LAYER 2: FLOW (M15) - ALL LIVE (idx-1)
// =================================================================
   double mid_o[], mid_h[], mid_l[], mid_c[];
   long mid_v[];
   datetime mid_t[];
   if(!FetchData(sym, InpTFMiddle, InpScanHistory, mid_t, mid_o, mid_h, mid_l, mid_c, mid_v))
      return false;

   int idx_live_mid = ArraySize(mid_c) - 1;
   double mid_atr   = Calc_ATR(mid_o, mid_h, mid_l, mid_c, InpATRPeriod, idx_live_mid);

   data.m15_momentum = Calc_LaguerreRSI(mid_o, mid_h, mid_l, mid_c, idx_live_mid);
   data.m15_vol_qual = Calc_RVOL(mid_v, InpRVOLPeriod, idx_live_mid);
   Calc_Squeeze_Full(sym, InpTFMiddle, mid_o, mid_h, mid_l, mid_c, idx_live_mid, data.m15_squeeze, data.m15_sqz_mom);
   data.m15_z_score  = Calc_ZScore(mid_o, mid_h, mid_l, mid_c, InpZScorePeriod, idx_live_mid);

   double vwap_series[];
   Calc_VWAP_Series(mid_t, mid_o, mid_h, mid_l, mid_c, mid_v, PERIOD_SESSION, vwap_series);
   data.m15_vwap_slope = CMetricsTools::CalculateSlope(vwap_series[idx_live_mid], vwap_series[idx_live_mid - InpSlopeLookback], mid_atr, InpSlopeLookback);

   double atr_f = Calc_ATR(mid_o, mid_h, mid_l, mid_c, 5, idx_live_mid);
   double atr_s = Calc_ATR(mid_o, mid_h, mid_l, mid_c, 50, idx_live_mid);
   data.m15_vola_regime = (atr_s!=0) ? atr_f/atr_s : 1.0;

   CSessionLevelsCalculator sess_calc;
   if(sess_calc.Init(PERIOD_D1))
     {
      SessionLevels sl;
      if(sess_calc.GetLevels(sym, mid_t[idx_live_mid], sl))
        {
         data.dist_pdh = CMetricsTools::CalculateDistance(mid_c[idx_live_mid], sl.prev_high, mid_atr);
         data.dist_pdl = CMetricsTools::CalculateDistance(mid_c[idx_live_mid], sl.prev_low, mid_atr);
        }
     }

   Calc_TSI_Values(mid_o, mid_h, mid_l, mid_c, idx_live_mid, data.m15_tsi_val, data.m15_tsi_hist);

// =================================================================
// LAYER 3: TRIGGER (M5) - ALL LIVE (idx-1)
// =================================================================
   double fast_o[], fast_h[], fast_l[], fast_c[];
   long fast_v[];
   datetime fast_t[];
   if(!FetchData(sym, InpTFFast, 300, fast_t, fast_o, fast_h, fast_l, fast_c, fast_v))
      return false;

   int idx_live_fast = ArraySize(fast_c) - 1;
   double fast_atr   = Calc_ATR(fast_o, fast_h, fast_l, fast_c, InpATRPeriod, idx_live_fast);

   data.spread_cost = CMetricsTools::CalculateSpreadCost(sym, fast_atr); // Calc cost on M5 ATR

   data.m5_momentum = Calc_LaguerreRSI(fast_o, fast_h, fast_l, fast_c, idx_live_fast);
   data.m5_vol_qual = Calc_RVOL(fast_v, InpRVOLPeriod, idx_live_fast);
   Calc_TSI_Values(fast_o, fast_h, fast_l, fast_c, idx_live_fast, data.m5_tsi_val, data.m5_tsi_hist);
   data.m5_velocity = Calc_Velocity(fast_c, fast_atr, 3, idx_live_fast);

// =================================================================
// COMPOSITES
// =================================================================
   if(data.m15_vol_qual > 0)
      data.vol_thrust = data.m5_vol_qual / data.m15_vol_qual;
   else
      data.vol_thrust = 0;

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

// Absorption: Use Last Closed M15 (idx_live_mid - 1) for safety
   int idx_cl_mid = idx_live_mid - 1;
   if(idx_cl_mid >= 0 && mid_atr > 0)
     {
      double body = MathAbs(mid_c[idx_cl_mid] - mid_o[idx_cl_mid]);
      CRelativeVolumeCalculator rv;
      rv.Init(InpRVOLPeriod);
      double bar_rvol = rv.CalculateSingle(ArraySize(mid_v), mid_v, idx_cl_mid);
      if(bar_rvol > 2.0 && body < (0.4 * mid_atr))
         data.absorption = "YES";
      else
         data.absorption = "NO";
     }
   else
      data.absorption = "-";

// MTF Align (Based on Hist direction)
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
//| WRAPPERS (Helpers) UPDATED FOR INDEX                             |
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

// Other wrappers updated to take 'int idx' and return buf[idx]
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
double Calc_ER(const double &o[], const double &h[], const double &l[], const double &c[], int p, int idx)
  {
   CEfficiencyRatioCalculator calc;
   if(!calc.Init(p))
      return 0;
   double buf[];
   int total=ArraySize(c);
   ArrayResize(buf, total);
   calc.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, buf);
   return buf[idx];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Calc_ZScore(const double &o[], const double &h[], const double &l[], const double &c[], int p, int idx)
  {
   CZScoreCalculator calc;
   if(!calc.Init(p))
      return 0;
   double buf[];
   int total=ArraySize(c);
   ArrayResize(buf, total);
   calc.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, buf);
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
//| WRAPPER UPDATE: Calc_Squeeze_Full                                |
//+------------------------------------------------------------------+
void Calc_Squeeze_Full(string sym, ENUM_TIMEFRAMES tf, const double &o[], const double &h[], const double &l[], const double &c[], int idx, string &state, double &mom_val)
  {
   int total = ArraySize(c);
   CSqueezeCalculator sqz;
// Use new input InpSqueezeMom
   if(!sqz.Init(InpSqueezeLength, InpBBMult, InpKCMult, InpSqueezeMom))
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
      mom_val = mom[idx]; // The momentum hist value
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Calc_LaguerreRSI(const double &o[], const double &h[], const double &l[], const double &c[], int idx)
  {
   CLaguerreRSICalculator calc;
   calc.Init(InpLaguerreGamma, 3, SMA);
   double lrsi[], sig[];
   int total=ArraySize(c);
   ArrayResize(lrsi, total);
   ArrayResize(sig, total);
   calc.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, lrsi, sig);
   return lrsi[idx] / 100.0;
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
//+------------------------------------------------------------------+
