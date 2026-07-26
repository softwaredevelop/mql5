//+------------------------------------------------------------------+
//|                                           Market_Scanner_Pro.mq5 |
//|                    QuantScan 10.38 - Historical Audit Master     |
//|                    Copyright 2026, xxxxxxxx                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "10.38" // Restored live Symbol BID pricing and dynamic live/historical Murrey price routing
#property description "Exports 'QuantScan' dataset for LLM Analysis."
#property description "Features High-Performance Object Caching and precise Historical Audits."
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
#include <MyIncludes\VHF_Calculator.mqh>
#include <MyIncludes\LinearRegression_Calculator.mqh>
#include <MyIncludes\VScore_Calculator.mqh>
#include <MyIncludes\Autocorrelation_Calculator.mqh>
#include <MyIncludes\VolumePressure_Calculator.mqh>

//--- Input Parameters
input group "Scanner Config"
input bool     InpUseMarketWatch = false;
input string   InpSymbolList     = "EURUSD,USDJPY,GBPUSD,USDCHF,AUDUSD,XAUUSD,US500,DE40,XTIUSD,ETHUSD";
input string   InpBenchmark      = "US500";
input string   InpForexBench     = "DX";
input string   InpBrokerTimeZone = "EET (UTC+2)";
input int      InpScanHistory    = 500;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "Historical Target Settings (For Backtesting/Audits)"
input bool     InpUseTargetTime  = false;             // Use Historical Target Time?
input datetime InpTargetTime     = D'2026.02.10 14:00'; // Target Evaluation Time (Broker Time)

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
input int      InpSqueezeMom     = 12;

input group "Output Settings"
input int      InpPrecision      = 3; // Decimal places for CSV Output

//--- QuantData Struct
struct QuantData
  {
   string            timestamp;
   string            symbol;
   double            price;
   string            alpha_str;
   string            beta_str;
   double            vhf;
   double            r2;
   string            zone;
   double            v_score_week;
   double            v_score_day;
   double            autocorr;
   double            vol_regime;
   string            sqz;
   double            sqz_mom;
   double            m15_vhf;
   double            m15_r2;
   double            dist_pdh;
   double            dist_pdl;
   double            velocity;
   double            v_pressure;
   double            vol_thrust;
   double            cost_atr;
   string            absorption;
   string            mtf_align;
   string            vwap_align;
   double            h1_tsi_hist;
   double            m15_tsi_hist;
   double            m5_tsi_hist;
  };

//+==================================================================+
//|             CLASS: CMarketScanner (Flyweight Engine)             |
//+==================================================================+
class CMarketScanner
  {
private:
   // Persistent Engines to avoid heap/stack allocation storms
   CATRCalculator             m_atr;
   CRelativeVolumeCalculator  m_rvol;
   CSqueezeCalculator         m_squeeze;
   CMurreyMathCalculator      m_murrey;
   CTSICalculator             m_tsi;
   CVHFCalculator             m_vhf;
   CLinearRegressionCalculator m_linreg;
   CVScoreCalculator          m_vscore_day;
   CVScoreCalculator          m_vscore_week;
   CAutocorrelationCalculator m_autocorr;
   CVolumePressureCalculator  m_vpressure;
   CSessionLevelsCalculator   m_sess;
   CMathStatisticsCalculator  m_stats;

   // Reuseable calculation buffers
   double                     m_temp_buf1[];
   double                     m_temp_buf2[];
   double                     m_temp_buf3[];
   double                     m_temp_buf4[];

   bool                       FetchData(string sym, ENUM_TIMEFRAMES tf, int count, datetime &t[], double &o[], double &h[], double &l[], double &c[], long &v[]);
   bool                       IsForexPair(string sym);
   string                     CalculateAbsorption(const double &o[], const double &h[], const double &l[], const double &c[], const long &v[], double atr, int idx);

public:
                     CMarketScanner(void) {}
                    ~CMarketScanner(void) {}

   bool                       Init(void);
   bool                       RunAnalysis(string sym, QuantData &data);
  };

//+------------------------------------------------------------------+
//| Init: Pre-allocate and initialize all engines once               |
//+------------------------------------------------------------------+
bool CMarketScanner::Init(void)
  {
   if(!m_atr.Init(InpATRPeriod, ATR_POINTS))
      return false;
   if(!m_rvol.Init(InpRVOLPeriod))
      return false;
   if(!m_squeeze.Init(InpSqueezeLength, InpBBMult, InpKCMult, InpSqueezeMom))
      return false;
   if(!m_vhf.Init(InpVHFPeriod, VHF_MODE_HIGH_LOW))
      return false;
   if(!m_linreg.Init(InpR2Period))
      return false;
   if(!m_vscore_day.Init(InpVScorePeriod, PERIOD_SESSION))
      return false;
   if(!m_vscore_week.Init(InpVScorePeriod, PERIOD_WEEK))
      return false;
   if(!m_autocorr.Init(InpAutoCorrPeriod))
      return false;
   if(!m_vpressure.Init(1))
      return false;
   if(!m_tsi.Init(InpTSI_Slow, EMA, InpTSI_Fast, EMA, InpTSI_Signal, EMA))
      return false;
   if(!m_sess.Init(PERIOD_D1))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| RunAnalysis: High-speed, allocation-free execution per symbol    |
//+------------------------------------------------------------------+
bool CMarketScanner::RunAnalysis(string sym, QuantData &data)
  {
   double slow_o[], slow_h[], slow_l[], slow_c[];
   long slow_v[];
   datetime slow_t[];
   if(!FetchData(sym, InpTFSlow, InpScanHistory, slow_t, slow_o, slow_h, slow_l, slow_c, slow_v))
      return false;

// Get precise H1 rates_total equivalent
   int h1_total = ArraySize(slow_c);
   int idx_l1 = h1_total - 1;

// 1. Beta / Alpha Caclulation (Optimized)
   bool is_benchmark = (sym == InpBenchmark || sym == InpForexBench);
   if(is_benchmark)
     {
      data.beta_str  = "1.0";
      data.alpha_str = "0.0";
     }
   else
     {
      string bench_sym = InpBenchmark;
      if(IsForexPair(sym) && SymbolSelect(InpForexBench, true))
         bench_sym = InpForexBench;

      double b_c[], dum_o[], dum_h[], dum_l[];
      long dum_v[];
      datetime b_t[];
      if(CDataSync::EnsureDataReady(bench_sym, InpTFSlow, InpScanHistory) &&
         FetchData(bench_sym, InpTFSlow, InpScanHistory, b_t, dum_o, dum_h, dum_l, b_c, dum_v))
        {
         int h1_size = ArraySize(slow_c);
         int bench_size = ArraySize(b_c);
         int lookback_beta = InpBetaLookback;

         double asset_subset[], bench_subset[];
         ArrayResize(asset_subset, lookback_beta);
         ArrayResize(bench_subset, lookback_beta);

         int valid_points = 0;
         for(int k = 0; k < lookback_beta; k++)
           {
            int a_idx = h1_size - 1 - k;
            if(a_idx < 0)
               break;

            datetime a_time = slow_t[a_idx];
            int b_idx_arr = ArrayBsearch(b_t, a_time);

            double a_val = slow_c[a_idx];
            double b_val = (b_idx_arr >= 0 && b_idx_arr < bench_size && b_t[b_idx_arr] == a_time) ? b_c[b_idx_arr] : 0.0;

            if(b_idx_arr < 0 || b_t[b_idx_arr] != a_time)
              {
               if(k > 0)
                  b_val = bench_subset[lookback_beta - k];
               else
                  b_val = b_c[MathMin(bench_size - 1, b_idx_arr > 0 ? b_idx_arr : 0)];
              }

            int sub_idx = lookback_beta - 1 - k;
            asset_subset[sub_idx] = a_val;
            bench_subset[sub_idx] = b_val;
            valid_points++;
           }

         if(valid_points > lookback_beta / 2)
           {
            double asset_ret[], bench_ret[];
            m_stats.ComputeReturns(asset_subset, asset_ret);
            m_stats.ComputeReturns(bench_subset, bench_ret);

            double beta_val = m_stats.CalculateBeta(asset_ret, bench_ret);
            double a_tot_beta = (asset_subset[lookback_beta - 1] - asset_subset[0]) / asset_subset[0];
            double b_tot_beta = (bench_subset[lookback_beta - 1] - bench_subset[0]) / bench_subset[0];
            double alpha_val = m_stats.CalculateAlpha(a_tot_beta, b_tot_beta, beta_val);

            data.beta_str  = DoubleToString(beta_val, 2);
            data.alpha_str = DoubleToString(alpha_val, 4);
           }
         else
           {
            data.beta_str = "0.0";
            data.alpha_str = "0.0";
           }
        }
     }

// 2. VHF (H1)
   ArrayResize(m_temp_buf1, h1_total);
   m_vhf.Calculate(h1_total, 0, PRICE_CLOSE, slow_o, slow_h, slow_l, slow_c, m_temp_buf1);
   data.vhf = m_temp_buf1[idx_l1];

// 3. R2 (Linear Regression H1)
   ArrayResize(m_temp_buf1, h1_total);
   ArrayResize(m_temp_buf2, h1_total);
   ArrayResize(m_temp_buf3, h1_total);
   m_linreg.CalculateState(h1_total, 0, slow_o, slow_h, slow_l, slow_c, PRICE_CLOSE, m_temp_buf1, m_temp_buf2, m_temp_buf3);
   data.r2 = m_temp_buf2[idx_l1];

// 4. Murrey Math Zones (Uses dynamic price routing: live iClose in live mode vs historical H1 close in target mode)
   m_murrey.Init(sym, InpTFSlow, InpMurreyPeriod, 0);
   double m_levels[];
   if(m_murrey.Calculate(m_levels))
     {
      double price = InpUseTargetTime ? slow_c[idx_l1] : iClose(sym, InpTFSlow, 0);
      if(price < m_levels[2])
         data.zone = "Extreme Low";
      else
         if(price > m_levels[10])
            data.zone = "Extreme High";
         else
            if(price >= m_levels[2] && price < m_levels[3])
               data.zone = "0/8-1/8 (Bottom)";
            else
               if(price >= m_levels[3] && price < m_levels[4])
                  data.zone = "1/8-2/8 (Weak)";
               else
                  if(price >= m_levels[4] && price < m_levels[6])
                     data.zone = "2/8-4/8 (Lower)";
                  else
                     if(price >= m_levels[6] && price < m_levels[8])
                        data.zone = "4/8-6/8 (Upper)";
                     else
                        if(price >= m_levels[8] && price < m_levels[9])
                           data.zone = "6/8-7/8 (Weak)";
                        else
                           data.zone = "7/8-8/8 (Top)";
     }
   else
      data.zone = "N/A";

// 5. TSI H1 Metrics (H1)
   ArrayResize(m_temp_buf1, h1_total);
   ArrayResize(m_temp_buf2, h1_total);
   ArrayResize(m_temp_buf3, h1_total);
   m_tsi.Calculate(h1_total, 0, PRICE_CLOSE, slow_o, slow_h, slow_l, slow_c, m_temp_buf1, m_temp_buf2, m_temp_buf3);
   data.h1_tsi_hist = m_temp_buf1[idx_l1] - m_temp_buf2[idx_l1];

//----------------------------------------------------------------
// LAYER 2: FLOW (M15)
//----------------------------------------------------------------
   double mid_o[], mid_h[], mid_l[], mid_c[];
   long mid_v[];
   datetime mid_t[];
   if(!FetchData(sym, InpTFMiddle, InpScanHistory, mid_t, mid_o, mid_h, mid_l, mid_c, mid_v))
      return false;

// Get precise M15 rates_total equivalent
   int m15_total = ArraySize(mid_c);
   int idx_l2 = m15_total - 1;

// 1. ATR Flow
   ArrayResize(m_temp_buf1, m15_total);
   m_atr.Calculate(m15_total, 0, mid_o, mid_h, mid_l, mid_c, m_temp_buf1);
   double mid_atr = m_temp_buf1[idx_l2];

// 2. V-Score Day (Reset: Session) (M15)
   ArrayResize(m_temp_buf2, m15_total);
   m_vscore_day.Calculate(m15_total, 0, mid_t, mid_o, mid_h, mid_l, mid_c, mid_v, mid_v, m_temp_buf2);
   data.v_score_day = m_temp_buf2[idx_l2];

// 3. V-Score Week (Using H1 data with correct h1_total parameter and idx_l1 index)
   ArrayResize(m_temp_buf3, h1_total);
   m_vscore_week.Calculate(h1_total, 0, slow_t, slow_o, slow_h, slow_l, slow_c, slow_v, slow_v, m_temp_buf3);
   data.v_score_week = m_temp_buf3[idx_l1];

// 4. Autocorrelation Lag-1 (M15)
   ArrayResize(m_temp_buf2, m15_total);
   m_autocorr.Calculate(m15_total, 0, PRICE_CLOSE, mid_o, mid_h, mid_l, mid_c, m_temp_buf2);
   data.autocorr = m_temp_buf2[idx_l2];

// 5. Volatility Regime (M15)
   CATRCalculator atr_reg_calc;
   double atr_fast_buf[], atr_slow_buf[];
   atr_reg_calc.Init(5, ATR_POINTS);
   atr_reg_calc.Calculate(m15_total, 0, mid_o, mid_h, mid_l, mid_c, atr_fast_buf);
   atr_reg_calc.Init(55, ATR_POINTS);
   atr_reg_calc.Calculate(m15_total, 0, mid_o, mid_h, mid_l, mid_c, atr_slow_buf);
   data.vol_regime = (atr_slow_buf[idx_l2] != 0.0) ? (atr_fast_buf[idx_l2] / atr_slow_buf[idx_l2]) : 1.0;

// 6. Squeeze (M15)
   double sqz_mom[], sqz_val[], sqz_col[];
   ArrayResize(sqz_mom, m15_total);
   ArrayResize(sqz_val, m15_total);
   ArrayResize(sqz_col, m15_total);
   m_squeeze.Calculate(m15_total, 0, PRICE_CLOSE, mid_o, mid_h, mid_l, mid_c, sqz_mom, sqz_val, sqz_col);
   data.sqz     = (sqz_col[idx_l2] == 1.0) ? "ON" : "OFF";
   data.sqz_mom = sqz_mom[idx_l2];

// 7. VHF & R2 (M15)
   ArrayResize(m_temp_buf1, m15_total);
   m_vhf.Calculate(m15_total, 0, PRICE_CLOSE, mid_o, mid_h, mid_l, mid_c, m_temp_buf1);
   data.m15_vhf = m_temp_buf1[idx_l2];

   ArrayResize(m_temp_buf1, m15_total);
   ArrayResize(m_temp_buf2, m15_total);
   ArrayResize(m_temp_buf3, m15_total);
   m_linreg.CalculateState(m15_total, 0, mid_o, mid_h, mid_l, mid_c, PRICE_CLOSE, m_temp_buf1, m_temp_buf2, m_temp_buf3);
   data.m15_r2 = m_temp_buf2[idx_l2];

// 8. Dist PDH / PDL (M15)
   SessionLevels sl;
   if(m_sess.GetLevels(sym, mid_t[idx_l2], sl))
     {
      data.dist_pdh = CMetricsTools::CalculateDistance(mid_c[idx_l2], sl.prev_high, mid_atr);
      data.dist_pdl = CMetricsTools::CalculateDistance(mid_c[idx_l2], sl.prev_low, mid_atr);
     }
   else
     {
      data.dist_pdh = 0.0;
      data.dist_pdl = 0.0;
     }

// 9. TSI M15 (M15)
   ArrayResize(m_temp_buf1, m15_total);
   ArrayResize(m_temp_buf2, m15_total);
   ArrayResize(m_temp_buf3, m15_total);
   m_tsi.Calculate(m15_total, 0, PRICE_CLOSE, mid_o, mid_h, mid_l, mid_c, m_temp_buf1, m_temp_buf2, m_temp_buf3);
   data.m15_tsi_hist = m_temp_buf1[idx_l2] - m_temp_buf2[idx_l2];

// 10. RVOL M15 for Thrust
   double rvol_m15 = m_rvol.CalculateSingle(m15_total, mid_v, idx_l2);

//----------------------------------------------------------------
// LAYER 3: TRIGGER (M5)
//----------------------------------------------------------------
   double fast_o[], fast_h[], fast_l[], fast_c[];
   long fast_v[];
   datetime fast_t[];
   if(!FetchData(sym, InpTFFast, 300, fast_t, fast_o, fast_h, fast_l, fast_c, fast_v))
      return false;

// Get precise M5 rates_total equivalent
   int m5_total = ArraySize(fast_c);
   int idx_l3 = m5_total - 1;

// 1. Volatility Trigger (M5)
   ArrayResize(m_temp_buf1, m5_total);
   m_atr.Calculate(m5_total, 0, fast_o, fast_h, fast_l, fast_c, m_temp_buf1);
   double fast_atr = m_temp_buf1[idx_l3];

// 2. Velocity
   data.velocity = (fast_atr > 0.0) ? CMetricsTools::CalculateSlope(fast_c[idx_l3], fast_c[idx_l3 - 5], fast_atr, 5) : 0.0;

// 3. Volume Pressure (Tick Delta Proxy) (M5)
   ArrayResize(m_temp_buf2, m5_total);
   m_vpressure.Calculate(m5_total, 0, fast_h, fast_l, fast_c, m_temp_buf2);
   data.v_pressure = m_temp_buf2[idx_l3];

// 4. Volume Thrust
   double rvol_m5  = m_rvol.CalculateSingle(m5_total, fast_v, idx_l3);
   data.vol_thrust = (rvol_m15 > 0.0) ? (rvol_m5 / rvol_m15) : 0.0;

// 5. Cost
   data.cost_atr = CMetricsTools::CalculateSpreadCost(sym, fast_atr);

// 6. TSI M5 (M5)
   ArrayResize(m_temp_buf1, m5_total);
   ArrayResize(m_temp_buf2, m5_total);
   ArrayResize(m_temp_buf3, m5_total);
   m_tsi.Calculate(m5_total, 0, PRICE_CLOSE, fast_o, fast_h, fast_l, fast_c, m_temp_buf1, m_temp_buf2, m_temp_buf3);
   data.m5_tsi_hist = m_temp_buf1[idx_l3] - m_temp_buf2[idx_l3];

//----------------------------------------------------------------
// LAYER 4: COMPOSITES & ALIGNMENT
//----------------------------------------------------------------

// 1. Institutional Absorption (Wyckoff VSA Logic) using normalized size (m15_total)
   data.absorption = CalculateAbsorption(mid_o, mid_h, mid_l, mid_c, mid_v, mid_atr, idx_l2 - 1);

// 2. MTF Align
   bool h1_bull  = (data.h1_tsi_hist > 0.0);
   bool m15_bull = (data.m15_tsi_hist > 0.0);
   bool m5_bull  = (data.m5_tsi_hist > 0.0);

   if(h1_bull == m15_bull && m15_bull == m5_bull)
      data.mtf_align = "FULL_" + (h1_bull ? "BULL" : "BEAR");
   else
      if(h1_bull == m15_bull)
         data.mtf_align = "MAJOR_" + (h1_bull ? "BULL" : "BEAR");
      else
         data.mtf_align = "MIXED";

// 3. VWAP Align
   bool day_bull  = (data.v_score_day > 0.0);
   bool week_bull = (data.v_score_week > 0.0);

   if(day_bull && week_bull)
      data.vwap_align = "FULL_BULL";
   else
      if(!day_bull && !week_bull)
         data.vwap_align = "FULL_BEAR";
      else
         data.vwap_align = "MIXED";

// --- EXACT TARGET TIME AND LIVE PRICE ALIGNMENTS ---
// Map precision timestamp to reflect the exact target minute (08:32 / 09:37)
   data.timestamp = InpUseTargetTime ? TimeToString(InpTargetTime, TIME_DATE|TIME_MINUTES)
                    : TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);

   data.symbol    = sym; // FIXED: Re-added the missing symbol assignment!

// RESTORED: Using live Bid price for the active symbol as requested for consistency
   data.price     = SymbolInfoDouble(sym, SYMBOL_BID);

   return true;
  }

//+------------------------------------------------------------------+
//| Helper: Dynamic pricing data fetcher with Historical Offset      |
//+------------------------------------------------------------------+
bool CMarketScanner::FetchData(string sym, ENUM_TIMEFRAMES tf, int count, datetime &t[], double &o[], double &h[], double &l[], double &c[], long &v[])
  {
   int start_bar = 0;

// If historical target scan is enabled, calculate the bar shift offset dynamically
   if(InpUseTargetTime)
     {
      start_bar = iBarShift(sym, tf, InpTargetTime, false);
      if(start_bar < 0)
         return false;
     }

// Synchronize history up to the target evaluation window
   if(!CDataSync::EnsureDataReady(sym, tf, start_bar + count))
      return false;

   ArraySetAsSeries(t, false);
   ArraySetAsSeries(o, false);
   ArraySetAsSeries(h, false);
   ArraySetAsSeries(l, false);
   ArraySetAsSeries(c, false);
   ArraySetAsSeries(v, false);

// Copy history window starting from historical offset
   if(CopyTime(sym, tf, start_bar, count, t) != count ||
      CopyOpen(sym, tf, start_bar, count, o) != count ||
      CopyHigh(sym, tf, start_bar, count, h) != count ||
      CopyLow(sym, tf, start_bar, count, l) != count ||
      CopyClose(sym, tf, start_bar, count, c) != count ||
      CopyTickVolume(sym, tf, start_bar, count, v) != count)
     {
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Helper: Detect Forex Pair                                        |
//+------------------------------------------------------------------+
bool CMarketScanner::IsForexPair(string sym)
  {
   if(sym == InpBenchmark || sym == InpForexBench)
      return false;

   if(StringFind(sym, "USD") != -1 || StringFind(sym, "EUR") != -1 ||
      StringFind(sym, "GBP") != -1 || StringFind(sym, "JPY") != -1 ||
      StringFind(sym, "CHF") != -1 || StringFind(sym, "AUD") != -1 ||
      StringFind(sym, "CAD") != -1 || StringFind(sym, "NZD") != -1 ||
      StringFind(sym, "XAU") != -1 || StringFind(sym, "XAG") != -1)
     {
      if(StringFind(sym, "XTI") != -1 || StringFind(sym, "UKO") != -1 ||
         StringFind(sym, "USO") != -1 || StringFind(sym, "BTC") != -1 ||
         StringFind(sym, "ETH") != -1)
         return false;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Helper: Calculate Institutional Absorption                       |
//+------------------------------------------------------------------+
string CMarketScanner::CalculateAbsorption(const double &o[], const double &h[], const double &l[], const double &c[], const long &v[], double atr, int idx)
  {
   if(idx < 0 || atr <= 0.0)
      return "-";

   double body = MathAbs(c[idx] - o[idx]);
   double total_range = h[idx] - l[idx];
   double bar_rvol = m_rvol.CalculateSingle(ArraySize(v), v, idx);

   bool high_effort = (bar_rvol > 2.0);
   bool low_result  = (body < (0.35 * atr));

   if(high_effort && low_result)
     {
      double close_pos = 0.5;
      if(total_range > 0.0)
         close_pos = (c[idx] - l[idx]) / total_range;

      if(close_pos > 0.66)
         return "BULL_ABS";
      else
         if(close_pos < 0.33)
            return "BEAR_ABS";
         else
            return "NEUT_ABS";
     }
   else
      if(bar_rvol > 3.5 && body < (0.6 * atr))
        {
         return "CLIMAX";
        }

   return "NO";
  }

//--- Global Scanner Engine Instance
CMarketScanner g_scanner;

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

// Initialize the high-performance global scanner
   if(!g_scanner.Init())
     {
      Print("Critical Error: Failed to initialize CMarketScanner Engine.");
      return;
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

// Sync Benchmark historical arrays if needed
   if(has_us500)
     {
      int start_bar_bench = 0;
      if(InpUseTargetTime)
         start_bar_bench = iBarShift(InpBenchmark, InpTFSlow, InpTargetTime, false);
      CDataSync::EnsureDataReady(InpBenchmark, InpTFSlow, start_bar_bench + InpScanHistory);
     }

// Dynamic CSV filename including target date if historical mode is active
   string time_str = InpUseTargetTime ? TimeToString(InpTargetTime, TIME_DATE|TIME_MINUTES) : TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
   StringReplace(time_str, ":", "");
   StringReplace(time_str, " ", "_");
   StringReplace(time_str, ".", "");
   string filename = "QuantScan_" + time_str + ".csv";

   int file_handle = FileOpen(filename, FILE_CSV|FILE_WRITE|FILE_ANSI, ";");
   if(file_handle == INVALID_HANDLE)
      return;

// --- SCAN & STORE ---
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
      if(g_scanner.RunAnalysis(sym, temp_data))
        {
         ArrayResize(results, success_count + 1);
         results[success_count] = temp_data;
         success_count++;
        }
      else
         Print("Scan Failed: ", sym);
     }

// --- BREADTH SCORE ---
   int bulls = 0;
   for(int i=0; i<success_count; i++)
     {
      if(results[i].h1_tsi_hist > 0)
         bulls++;
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
   header += StringFormat("ALPHA_%s;BETA_%s;VHF_%s;R2_%s;ZONE_%s;", str_slow, str_slow, str_slow, str_slow, str_slow);
   header += StringFormat("V_SCORE_W1_%s;V_SCORE_D1_%s;AUTOCORR_%s;VOL_REGIME_%s;SQZ_%s;SQZ_MOM_%s;VHF_%s;R2_%s;DIST_PDH;DIST_PDL;", str_mid, str_mid, str_mid, str_mid, str_mid, str_mid, str_mid, str_mid);
   header += StringFormat("VEL_%s;V_PRES_%s;VOL_THRUST;COST_ATR_%s;", str_fast, str_fast, str_fast);
   header += "ABSORPTION;MTF_ALIGN;VWAP_ALIGN";

   FileWrite(file_handle, header);

// --- WRITE DATA ---
   for(int i=0; i<success_count; i++)
     {
      FileWrite(file_handle,
                results[i].timestamp,
                results[i].symbol,
                DoubleToString(results[i].price, (int)SymbolInfoInteger(results[i].symbol, SYMBOL_DIGITS)),
                results[i].alpha_str,
                results[i].beta_str,
                DoubleToString(results[i].vhf, InpPrecision),
                DoubleToString(results[i].r2, InpPrecision),
                results[i].zone,
                DoubleToString(results[i].v_score_week, InpPrecision),
                DoubleToString(results[i].v_score_day, InpPrecision),
                DoubleToString(results[i].autocorr, InpPrecision),
                DoubleToString(results[i].vol_regime, InpPrecision),
                results[i].sqz,
                DoubleToString(results[i].sqz_mom, InpPrecision),
                DoubleToString(results[i].m15_vhf, InpPrecision),
                DoubleToString(results[i].m15_r2, InpPrecision),
                DoubleToString(results[i].dist_pdh, InpPrecision),
                DoubleToString(results[i].dist_pdl, InpPrecision),
                DoubleToString(results[i].velocity, InpPrecision),
                DoubleToString(results[i].v_pressure, InpPrecision),
                DoubleToString(results[i].vol_thrust, InpPrecision),
                DoubleToString(results[i].cost_atr, InpPrecision),
                results[i].absorption,
                results[i].mtf_align,
                results[i].vwap_align
               );
     }

   FileClose(file_handle);
   Print("Done. File: ", filename);
  }

//+------------------------------------------------------------------+
//| Helper: Get Sentiment String for TF                              |
//+------------------------------------------------------------------+
string GetSentimentForTF(ENUM_TIMEFRAMES tf)
  {
   int start_bar_bench = 0;
   if(InpUseTargetTime)
     {
      start_bar_bench = iBarShift(InpBenchmark, tf, InpTargetTime, false);
      if(start_bar_bench < 0)
         return "N/A";
     }

   if(!CDataSync::EnsureDataReady(InpBenchmark, tf, start_bar_bench + 2))
      return "N/A";
   if(!CDataSync::EnsureDataReady(InpForexBench, tf, start_bar_bench + 2))
      return "N/A";

   double u_clos[2], d_clos[2];
   if(CopyClose(InpBenchmark, tf, start_bar_bench, 2, u_clos) != 2)
      return "N/A";
   if(CopyClose(InpForexBench, tf, start_bar_bench, 2, d_clos) != 2)
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

   return StringFormat("%s: %s (US:%.2f%% DX:%.2f%%)", tf_name, state, u_pct, d_pct);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
