//+------------------------------------------------------------------+
//|                                           Market_Scanner_Pro.mq5 |
//|                    QuantScan 4.1 - Header Fix                    |
//|                    Copyright 2026, xxxxxxxx                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "4.10" // Re-added Dynamic Header logic
#property description "Exports 'QuantScan 4.0' for LLM Analysis."
#property description "Includes Trend, Volatility, Stats + Beta/Alpha metrics."
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
input ENUM_TIMEFRAMES InpTFFast  = PERIOD_M15;
input ENUM_TIMEFRAMES InpTFSlow  = PERIOD_H1;

input group "Metric Settings"
input int      InpDSMAPeriod     = 40;
input double   InpLaguerreGamma  = 0.50;
input int      InpMurreyPeriod   = 64;
input int      InpATRPeriod      = 14;
input int      InpRSBars         = 24;
input int      InpRVOLPeriod     = 20;
input int      InpERPeriod       = 10;
input int      InpZScorePeriod   = 20;

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

   // --- H1 ---
   double            trend_score;
   double            trend_qual;
   string            zone;
   double            rel_strength;
   double            beta;
   double            alpha;

   // --- M15 ---
   double            momentum;
   double            vol_qual;
   string            squeeze;
   double            z_score;
   double            vola_regime;
   string            tsi_dir;

   // --- Composites ---
   double            rev_prob;
   string            absorption;
  };

//+------------------------------------------------------------------+
//| Helper: Detect Asset Class                                       |
//+------------------------------------------------------------------+
bool IsForexPair(string sym)
  {
   if(StringFind(sym, "USD") != -1 || StringFind(sym, "EUR") != -1 ||
      StringFind(sym, "GBP") != -1 || StringFind(sym, "JPY") != -1 ||
      StringFind(sym, "CHF") != -1 || StringFind(sym, "AUD") != -1 ||
      StringFind(sym, "CAD") != -1 || StringFind(sym, "NZD") != -1)
     {
      if(StringFind(sym, "XAU") != -1)
         return false;
      if(StringFind(sym, "XTI") != -1)
         return false;
      if(StringFind(sym, "WTI") != -1)
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

   double bench_change_pct = 0.0;
   bool bench_global_ready = SymbolSelect(InpBenchmark, true);
   bool bench_forex_ready  = SymbolSelect(InpForexBench, true);

   if(!bench_global_ready)
      Print("Warning: Global Benchmark '", InpBenchmark, "' not found.");
   if(!bench_forex_ready)
      Print("Warning: Forex Benchmark '", InpForexBench, "' not found.");

   string filename = "QuantScan_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + ".csv";
   StringReplace(filename, ":", "");
   StringReplace(filename, " ", "_");

   int file_handle = FileOpen(filename, FILE_CSV|FILE_WRITE|FILE_ANSI, ";");
   if(file_handle == INVALID_HANDLE)
      return;

// --- DYNAMIC HEADER GENERATION ---
   string str_slow = EnumToString(InpTFSlow);
   string str_fast = EnumToString(InpTFFast);
   StringReplace(str_slow, "PERIOD_", "");
   StringReplace(str_fast, "PERIOD_", "");

   string header = "";
   header += "TIME (" + InpBrokerTimeZone + ");";
   header += "SYMBOL;";
   header += "PRICE;";

// Context (Slow)
   header += StringFormat("TREND_SCORE_%s;", str_slow);
   header += StringFormat("TREND_QUAL_%s;", str_slow);
   header += StringFormat("ZONE_%s;", str_slow);
   header += StringFormat("REL_STRENGTH_%s;", str_slow);
   header += StringFormat("BETA_%s;", str_slow);
   header += StringFormat("ALPHA_%s;", str_slow);

// Trigger (Fast)
   header += StringFormat("MOMENTUM_%s;", str_fast);
   header += StringFormat("VOL_QUAL_%s;", str_fast);
   header += StringFormat("SQUEEZE_%s;", str_fast);
   header += StringFormat("Z_SCORE_%s;", str_fast);
   header += StringFormat("VOL_REGIME_%s;", str_fast);
   header += StringFormat("TSI_DIR_%s;", str_fast);

// Composites (Mixed logic, no suffix needed as discussed)
   header += "REVERSION_PROB;";
   header += "ABSORPTION";

   FileWrite(file_handle, header);

   PrintFormat("Scanning %d symbols...", total_symbols);

   for(int i=0; i<total_symbols; i++)
     {
      string sym = symbols[i];
      StringTrimLeft(sym);
      StringTrimRight(sym);
      QuantData data;
      ZeroMemory(data);

      if(RunQuantAnalysis(sym, data))
        {
         FileWrite(file_handle,
                   data.timestamp,
                   data.symbol,
                   DoubleToString(data.price, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS)),
                   DoubleToString(data.trend_score, 2),
                   DoubleToString(data.trend_qual, 2),
                   data.zone,
                   DoubleToString(data.rel_strength, 2) + "%",
                   DoubleToString(data.beta, 2),
                   DoubleToString(data.alpha, 4),
                   DoubleToString(data.momentum, 2),
                   DoubleToString(data.vol_qual, 2),
                   data.squeeze,
                   DoubleToString(data.z_score, 2),
                   DoubleToString(data.vola_regime, 2),
                   data.tsi_dir,
                   DoubleToString(data.rev_prob, 0) + "%",
                   data.absorption
                  );
        }
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
// PHASE 1: H1 CONTEXT
// =================================================================
   double h1_o[], h1_h[], h1_l[], h1_c[];
   long h1_v[];
   datetime h1_t[];
   if(!FetchData(sym, InpTFSlow, InpScanHistory, h1_t, h1_o, h1_h, h1_l, h1_c, h1_v))
      return false;

   double h1_atr = Calc_ATR(h1_o, h1_h, h1_l, h1_c, InpATRPeriod);
   if(h1_atr == 0)
      return false;

   data.trend_score = Calc_DSMA_Score(h1_o, h1_h, h1_l, h1_c, h1_atr);
   data.trend_qual  = Calc_ER(h1_o, h1_h, h1_l, h1_c, InpERPeriod);
   data.zone        = Calc_MurreyZone(sym, InpTFSlow);

// --- BETA / ALPHA Calculation ---
   string bench_sym = InpBenchmark;
   if(IsForexPair(sym) && SymbolSelect(InpForexBench, true))
      bench_sym = InpForexBench;

   double bench_c[];
   if(CopyClose(bench_sym, InpTFSlow, 0, InpBetaLookback+2, bench_c) > InpBetaLookback)
     {
      CMathStatisticsCalculator stats;
      double asset_ret[], bench_ret[];

      int h1_size = ArraySize(h1_c);
      double asset_subset[];
      ArrayResize(asset_subset, InpBetaLookback);
      double bench_subset[];
      ArrayResize(bench_subset, InpBetaLookback);

      for(int k=0; k<InpBetaLookback; k++)
        {
         asset_subset[k] = h1_c[h1_size - InpBetaLookback + k];
         bench_subset[k] = bench_c[ArraySize(bench_c) - InpBetaLookback + k];
        }

      stats.ComputeReturns(asset_subset, asset_ret);
      stats.ComputeReturns(bench_subset, bench_ret);

      data.beta = stats.CalculateBeta(asset_ret, bench_ret);

      double a_tot = (asset_subset[InpBetaLookback-1] - asset_subset[0]) / asset_subset[0];
      double b_tot = (bench_subset[InpBetaLookback-1] - bench_subset[0]) / bench_subset[0];
      data.alpha = stats.CalculateAlpha(a_tot, b_tot, data.beta);

      data.rel_strength = (a_tot - b_tot) * 100.0;
     }
   else
     {
      data.beta = 0;
      data.alpha = 0;
      data.rel_strength = 0;
     }

// =================================================================
// PHASE 2: M15 TRIGGER
// =================================================================
   double m15_o[], m15_h[], m15_l[], m15_c[];
   long m15_v[];
   datetime m15_t[];
   if(!FetchData(sym, InpTFFast, InpScanHistory, m15_t, m15_o, m15_h, m15_l, m15_c, m15_v))
      return false;

   double m15_atr = Calc_ATR(m15_o, m15_h, m15_l, m15_c, InpATRPeriod);

   data.momentum = Calc_LaguerreRSI(m15_o, m15_h, m15_l, m15_c);
   data.vol_qual = Calc_RVOL(m15_v, InpRVOLPeriod);
   data.squeeze  = Calc_Squeeze(sym, InpTFFast, m15_o, m15_h, m15_l, m15_c);
   data.z_score  = Calc_ZScore(m15_o, m15_h, m15_l, m15_c, InpZScorePeriod);

   double atr_fast = Calc_ATR(m15_o, m15_h, m15_l, m15_c, 5);
   double atr_slow = Calc_ATR(m15_o, m15_h, m15_l, m15_c, 50);
   if(atr_slow != 0)
      data.vola_regime = atr_fast / atr_slow;
   else
      data.vola_regime = 1.0;

   Calc_TSI_Dir(m15_o, m15_h, m15_l, m15_c, data.tsi_dir);

// =================================================================
// PHASE 3: COMPOSITE METRICS
// =================================================================
   double score = 0;
   if(MathAbs(data.z_score) > 3.0)
      score += 40;
   else
      if(MathAbs(data.z_score) > 2.0)
         score += 20;
   if(StringFind(data.zone, "Extreme") >= 0)
      score += 30;
   if(data.momentum > 0.90 || data.momentum < 0.10)
      score += 30;
   data.rev_prob = score;

   int idx_cl = ArraySize(m15_c) - 2;
   if(idx_cl >= 0 && m15_atr > 0)
     {
      double body = MathAbs(m15_c[idx_cl] - m15_o[idx_cl]);
      CRelativeVolumeCalculator rv_calc;
      rv_calc.Init(InpRVOLPeriod);
      double bar_rvol = rv_calc.CalculateSingle(ArraySize(m15_v), m15_v, idx_cl);

      if(bar_rvol > 2.0 && body < (0.4 * m15_atr))
         data.absorption = "YES";
      else
         data.absorption = "NO";
     }
   else
      data.absorption = "-";

   return true;
  }

//+------------------------------------------------------------------+
//| HELPERS / WRAPPERS                                               |
//+------------------------------------------------------------------+
bool FetchData(string sym, ENUM_TIMEFRAMES tf, int count, datetime &t[], double &o[], double &h[], double &l[], double &c[], long &v[])
  {
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
double Calc_ER(const double &o[], const double &h[], const double &l[], const double &c[], int p)
  {
   CEfficiencyRatioCalculator calc;
   if(!calc.Init(p))
      return 0;
   double buf[];
   int total = ArraySize(c);
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
   int total = ArraySize(c);
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
