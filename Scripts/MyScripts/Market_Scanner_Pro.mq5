//+------------------------------------------------------------------+
//|                                           Market_Scanner_Pro.mq5 |
//|                    QuantScan 3.1 - Professional Market Export    |
//|                    Copyright 2026, xxxxxxxx                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.30" // Timezone input + RS Lookback + History Control
#property description "Exports 'QuantScan 3.0' dataset for LLM Analysis."
#property description "Includes Relative Strength and Institutional Metrics."
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

//--- Input Parameters ---
input group "Scanner Config"
input bool     InpUseMarketWatch = false;    // Scan Market Watch?
input string   InpSymbolList     = "EURUSD,USDJPY,GBPUSD,USDCHF,AUDUSD,XAUUSD,US500,DE40,XTIUSD,ETHUSD";
input string   InpBenchmark      = "US500";  // Benchmark for Relative Strength
input string   InpBrokerTimeZone = "EET (UTC+2)"; // Broker Timezone Name (for CSV Header)
input int      InpScanHistory    = 500;      // Max History Bars to fetch

input group "Timeframes"
input ENUM_TIMEFRAMES InpTFFast  = PERIOD_M15; // Trigger / Execution
input ENUM_TIMEFRAMES InpTFSlow  = PERIOD_H1;  // Context / Trend

input group "Metric Settings"
input int      InpDSMAPeriod     = 40;
input double   InpLaguerreGamma  = 0.50;
input int      InpMurreyPeriod   = 64;
input int      InpATRPeriod      = 14;
input int      InpRSBars         = 24;   // Relative Strength Lookback (Bars on Slow TF)
input int      InpRVOLPeriod     = 20;   // Relative Volume Lookback
input int      InpERPeriod       = 10;   // Efficiency Ratio Lookback
input int      InpZScorePeriod   = 20;   // Z-Score Lookback

input group "TSI Settings"
input int      InpTSI_Slow       = 25;
input int      InpTSI_Fast       = 13;
input int      InpTSI_Signal     = 13;

input group "Squeeze Settings"
input int      InpSqueezeLength  = 20;
input double   InpBBMult         = 2.0;
input double   InpKCMult         = 1.5;

//--- Struct for QuantScan 3.0 Data
struct QuantData
  {
   string            timestamp;
   string            symbol;
   double            price;

   // --- H1 Context ---
   double            trend_score;      // DSMA Normalized Score
   double            trend_qual;       // Efficiency Ratio (ER)
   string            zone;             // Murrey Math Zone
   double            rel_strength;     // Relative Strength vs Benchmark

   // --- M15 Execution ---
   double            momentum;         // Laguerre RSI
   double            vol_qual;         // Relative Volume (RVOL)
   string            squeeze;          // ON/OFF
   double            z_score;          // Statistical Deviation
   double            vola_regime;      // ATR(5)/ATR(50) Ratio
   string            tsi_dir;          // TSI Direction

   // --- Composite Metrics ---
   double            rev_prob;         // Mean Reversion Probability (0-100)
   string            absorption;       // Institutional Absorption (YES/NO)
  };

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

// 2. Pre-Calculate Benchmark Performance
   double bench_change_pct = 0.0;

   if(!SymbolSelect(InpBenchmark, true))
     {
      Print("Warning: Benchmark '", InpBenchmark, "' not found. RS will be 0.");
     }
   else
     {
      double b_close[], b_open[];
      // Lookback based on InpRSBars input
      if(CopyClose(InpBenchmark, InpTFSlow, 1, 1, b_close) > 0 &&
         CopyOpen(InpBenchmark, InpTFSlow, InpRSBars, 1, b_open) > 0) // Uses user defined lookback
        {
         if(b_open[0] != 0)
            bench_change_pct = ((b_close[0] - b_open[0]) / b_open[0]) * 100.0;
         PrintFormat("Benchmark (%s) %d-Bar Change: %.2f%%", InpBenchmark, InpRSBars, bench_change_pct);
        }
     }

// 3. Prepare CSV
   string filename = "QuantScan_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + ".csv";
   StringReplace(filename, ":", "");
   StringReplace(filename, " ", "_");

   int file_handle = FileOpen(filename, FILE_CSV|FILE_WRITE|FILE_ANSI, ";");
   if(file_handle == INVALID_HANDLE)
     {
      Print("Error: Cannot write CSV.");
      return;
     }

// 4. Header - Now includes Timezone info
   string time_header = "TIME (" + InpBrokerTimeZone + ")";

   FileWrite(file_handle,
             time_header, "SYMBOL", "PRICE",
             "TREND_SCORE", "TREND_QUAL", "ZONE", "REL_STRENGTH", // H1 Context
             "MOMENTUM", "VOL_QUAL", "SQUEEZE", "Z_SCORE", "VOL_REGIME", "TSI_DIR", // M15 Data
             "REVERSION_PROB", "ABSORPTION" // Composites
            );

// 5. Main Loop
   PrintFormat("Scanning %d symbols...", total_symbols);

   for(int i=0; i<total_symbols; i++)
     {
      string sym = symbols[i];
      StringTrimLeft(sym);
      StringTrimRight(sym);

      QuantData data;
      ZeroMemory(data);

      // Compute
      if(RunQuantAnalysis(sym, bench_change_pct, data))
        {
         FileWrite(file_handle,
                   data.timestamp,
                   data.symbol,
                   DoubleToString(data.price, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS)),
                   DoubleToString(data.trend_score, 2),
                   DoubleToString(data.trend_qual, 2),
                   data.zone,
                   DoubleToString(data.rel_strength, 2) + "%",
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
      else
        {
         Print("Failed: ", sym);
        }
     }

   FileClose(file_handle);
   Print("Success! Data exported to: ", filename);
  }

//+------------------------------------------------------------------+
//| Core Logic: Run Quant Analysis                                   |
//+------------------------------------------------------------------+
bool RunQuantAnalysis(string sym, double bench_change, QuantData &data)
  {
// --- Common Data ---
   data.timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
   StringReplace(data.timestamp, ".", ".");
   data.symbol    = sym;
   data.price     = SymbolInfoDouble(sym, SYMBOL_BID);

// =================================================================
// PHASE 1: H1 CONTEXT
// =================================================================

// Fetch H1 Data
   double h1_o[], h1_h[], h1_l[], h1_c[];
   long   h1_v[];
   datetime h1_t[];
// Use InpScanHistory instead of hardcoded 300
   if(!FetchData(sym, InpTFSlow, InpScanHistory, h1_t, h1_o, h1_h, h1_l, h1_c, h1_v))
      return false;

// 1. H1 ATR
   double h1_atr = Calc_ATR(h1_o, h1_h, h1_l, h1_c, InpATRPeriod);
   if(h1_atr == 0)
      return false;

// 2. Trend Score
   data.trend_score = Calc_DSMA_Score(h1_o, h1_h, h1_l, h1_c, h1_atr);

// 3. Trend Quality
   data.trend_qual = Calc_EfficiencyRatio(h1_c, InpERPeriod);

// 4. Zone
   data.zone = Calc_MurreyZone(sym, InpTFSlow);

// 5. Relative Strength
   double sym_change = 0;
   int total_h1 = ArraySize(h1_c);
// Uses InpRSBars input for lookback
   if(total_h1 > InpRSBars + 1)
     {
      double c_now = h1_c[total_h1-2]; // Close[1]
      double o_old = h1_o[total_h1-2-(InpRSBars-1)]; // Match Benchmark logic
      if(o_old != 0)
         sym_change = ((c_now - o_old) / o_old) * 100.0;
     }
   data.rel_strength = sym_change - bench_change;


// =================================================================
// PHASE 2: M15 TRIGGER
// =================================================================

// Fetch M15 Data
   double m15_o[], m15_h[], m15_l[], m15_c[];
   long   m15_v[];
   datetime m15_t[];
   if(!FetchData(sym, InpTFFast, InpScanHistory, m15_t, m15_o, m15_h, m15_l, m15_c, m15_v))
      return false;

   double m15_atr = Calc_ATR(m15_o, m15_h, m15_l, m15_c, InpATRPeriod);

// 1. Momentum
   data.momentum = Calc_LaguerreRSI(m15_o, m15_h, m15_l, m15_c);

// 2. Volume Quality
   data.vol_qual = Calc_RVOL(m15_v, InpRVOLPeriod);

// 3. Squeeze
   data.squeeze = Calc_Squeeze(sym, InpTFFast, m15_o, m15_h, m15_l, m15_c);

// 4. Z-Score
   data.z_score = Calc_ZScore(m15_c, InpZScorePeriod);

// 5. Volatility Regime
   double atr_fast = Calc_ATR(m15_o, m15_h, m15_l, m15_c, 5);
   double atr_slow = Calc_ATR(m15_o, m15_h, m15_l, m15_c, 50);
   if(atr_slow != 0)
      data.vola_regime = atr_fast / atr_slow;
   else
      data.vola_regime = 1.0;

// 6. TSI Direction
   Calc_TSI_Dir(m15_o, m15_h, m15_l, m15_c, data.tsi_dir);


// =================================================================
// PHASE 3: COMPOSITE METRICS
// =================================================================

// A. Mean Reversion Probability
   double score = 0;
   double abs_z = MathAbs(data.z_score);
   if(abs_z > 3.0)
      score += 40;
   else
      if(abs_z > 2.0)
         score += 20;

   if(StringFind(data.zone, "Extreme") >= 0 || StringFind(data.zone, "8/8") >= 0 || StringFind(data.zone, "0/8") >= 0)
      score += 30;

   if(data.momentum > 0.90 || data.momentum < 0.10)
      score += 30;

   data.rev_prob = score;

// B. Institutional Absorption
   int last_idx = ArraySize(m15_c) - 2; // Index of last completed bar

   if(last_idx >= 0 && m15_atr > 0)
     {
      double body = MathAbs(m15_c[last_idx] - m15_o[last_idx]);
      double bar_rvol = Calc_RVOL_Single(m15_v, InpRVOLPeriod, last_idx);

      if(bar_rvol > 2.0 && body < (0.4 * m15_atr))
         data.absorption = "YES";
      else
         data.absorption = "NO";
     }
   else
     {
      data.absorption = "-";
     }

   return true;
  }

//+------------------------------------------------------------------+
//| WRAPPER: Fetch Data                                              |
//+------------------------------------------------------------------+
bool FetchData(string sym, ENUM_TIMEFRAMES tf, int count, datetime &t[], double &o[], double &h[], double &l[], double &c[], long &v[])
  {
   ArraySetAsSeries(t, false);
   ArraySetAsSeries(o, false);
   ArraySetAsSeries(h, false);
   ArraySetAsSeries(l, false);
   ArraySetAsSeries(c, false);
   ArraySetAsSeries(v, false);

   if(CopyTime(sym, tf, 0, count, t) != count)
      return false;
   if(CopyOpen(sym, tf, 0, count, o) != count)
      return false;
   if(CopyHigh(sym, tf, 0, count, h) != count)
      return false;
   if(CopyLow(sym, tf, 0, count, l) != count)
      return false;
   if(CopyClose(sym, tf, 0, count, c) != count)
      return false;
   if(CopyTickVolume(sym, tf, 0, count, v) != count)
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//| WRAPPER: ATR                                                     |
//+------------------------------------------------------------------+
double Calc_ATR(const double &o[], const double &h[], const double &l[], const double &c[], int p)
  {
   CATRCalculator calc;
   if(!calc.Init(p, ATR_POINTS))
      return 0;
   double buf[];
   int total = ArraySize(c);
   calc.Calculate(total, 0, o, h, l, c, buf);
   return buf[total-1];
  }

//+------------------------------------------------------------------+
//| WRAPPER: DSMA Score                                              |
//+------------------------------------------------------------------+
double Calc_DSMA_Score(const double &o[], const double &h[], const double &l[], const double &c[], double atr)
  {
   CDSMACalculator calc;
   if(!calc.Init(InpDSMAPeriod))
      return 0;
   double buf[];
   int total = ArraySize(c);
   ArrayResize(buf, total);
   calc.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, buf);

   if(atr == 0)
      return 0;
   return (c[total-1] - buf[total-1]) / atr;
  }

//+------------------------------------------------------------------+
//| WRAPPER: RVOL (Average)                                          |
//+------------------------------------------------------------------+
double Calc_RVOL(const long &vol[], int period)
  {
   return Calc_RVOL_Single(vol, period, ArraySize(vol)-1);
  }

//+------------------------------------------------------------------+
//| WRAPPER: RVOL (Specific Index)                                   |
//+------------------------------------------------------------------+
double Calc_RVOL_Single(const long &vol[], int period, int index)
  {
   if(index < period)
      return 1.0;
   double sum = 0;
   for(int i=1; i<=period; i++)
      sum += (double)vol[index - i];
   double avg = sum / period;
   if(avg == 0)
      return 0;
   return (double)vol[index] / avg;
  }

//+------------------------------------------------------------------+
//| WRAPPER: Z-Score                                                 |
//+------------------------------------------------------------------+
double Calc_ZScore(const double &price[], int period)
  {
   int total = ArraySize(price);
   if(total <= period)
      return 0;
   double sum = 0;
   for(int i=0; i<period; i++)
      sum += price[total-1-i];
   double sma = sum / period;
   double sum_sq = 0;
   for(int i=0; i<period; i++)
      sum_sq += MathPow(price[total-1-i] - sma, 2);
   double std_dev = MathSqrt(sum_sq / period);
   if(std_dev == 0)
      return 0;
   return (price[total-1] - sma) / std_dev;
  }

//+------------------------------------------------------------------+
//| WRAPPER: Efficiency Ratio (ER)                                   |
//+------------------------------------------------------------------+
double Calc_EfficiencyRatio(const double &price[], int period)
  {
   int total = ArraySize(price);
   if(total <= period)
      return 0;
   double net_change = MathAbs(price[total-1] - price[total-1-period]);
   double sum_change = 0;
   for(int i=0; i<period; i++)
      sum_change += MathAbs(price[total-1-i] - price[total-1-i-1]);
   if(sum_change == 0)
      return 0;
   return net_change / sum_change;
  }

//+------------------------------------------------------------------+
//| WRAPPER: Squeeze                                                 |
//+------------------------------------------------------------------+
string Calc_Squeeze(string sym, ENUM_TIMEFRAMES tf, const double &o[], const double &h[], const double &l[], const double &c[])
  {
   int total = ArraySize(c);
   CBollingerBandsCalculator bb;
   if(!bb.Init(InpSqueezeLength, InpBBMult, SMA))
      return "ERR";
   double b_ma[], b_up[], b_lo[];
   ArrayResize(b_ma, total);
   ArrayResize(b_up, total);
   ArrayResize(b_lo, total);
   bb.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, b_ma, b_up, b_lo);

   CKeltnerChannelCalculator kc;
   if(!kc.Init(InpSqueezeLength, SMA, InpSqueezeLength, InpKCMult, ATR_SOURCE_STANDARD))
      return "ERR";
   double k_ma[], k_up[], k_lo[];
   ArrayResize(k_ma, total);
   ArrayResize(k_up, total);
   ArrayResize(k_lo, total);
   kc.Calculate(total, 0, o, h, l, c, PRICE_CLOSE, k_ma, k_up, k_lo);

   int idx = total - 1;
   bool squeeze_on = (b_up[idx] < k_up[idx]) && (b_lo[idx] > k_lo[idx]);
   return squeeze_on ? "ON" : "OFF";
  }

//+------------------------------------------------------------------+
//| WRAPPER: Laguerre RSI                                            |
//+------------------------------------------------------------------+
double Calc_LaguerreRSI(const double &o[], const double &h[], const double &l[], const double &c[])
  {
   CLaguerreRSICalculator calc;
   if(!calc.Init(InpLaguerreGamma, 3, SMA))
      return 0;
   double lrsi[], sig[];
   int total = ArraySize(c);
   ArrayResize(lrsi, total);
   ArrayResize(sig, total);
   calc.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, lrsi, sig);
   return lrsi[total-1] / 100.0;
  }

//+------------------------------------------------------------------+
//| WRAPPER: TSI Direction                                           |
//+------------------------------------------------------------------+
void Calc_TSI_Dir(const double &o[], const double &h[], const double &l[], const double &c[], string &dir)
  {
   CTSICalculator calc;
   if(!calc.Init(InpTSI_Slow, EMA, InpTSI_Fast, EMA, InpTSI_Signal, EMA))
     {
      dir="ERR";
      return;
     }
   double tsi[], sig[], osc[];
   int total = ArraySize(c);
   ArrayResize(tsi, total);
   ArrayResize(sig, total);
   ArrayResize(osc, total);
   calc.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, tsi, sig, osc);
   if(tsi[total-1] > sig[total-1])
      dir = "BULL";
   else
      dir = "BEAR";
  }

//+------------------------------------------------------------------+
//| WRAPPER: Murrey Math                                             |
//+------------------------------------------------------------------+
string Calc_MurreyZone(string symbol, ENUM_TIMEFRAMES tf)
  {
   CMurreyMathCalculator calc;
   if(!calc.Init(symbol, tf, InpMurreyPeriod, 0))
      return "N/A";
   double levels[];
   if(!calc.Calculate(levels))
      return "N/A";

   double price = SymbolInfoDouble(symbol, SYMBOL_BID);
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
   if(price >= levels[9] && price <= levels[10])
      return "7/8-8/8 (Top)";

   return "Middle";
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
