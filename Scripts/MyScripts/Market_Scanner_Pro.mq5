//+------------------------------------------------------------------+
//|                                           Market_Scanner_Pro.mq5 |
//|                    QuantScan 2.1 - Professional Market Export    |
//|                    Copyright 2026, xxxxxxxx                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.10" // Added Squeeze & TSI inputs
#property description "Exports 'QuantScan 2.0' dataset for LLM Analysis."
#property description "Combines Trend Quality, Volume, and Statistical metrics."
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

input group "Timeframes"
input ENUM_TIMEFRAMES InpTFFast  = PERIOD_M15; // Trigger / Execution
input ENUM_TIMEFRAMES InpTFSlow  = PERIOD_H1;  // Context / Trend

input group "Metric Settings"
input int      InpDSMAPeriod     = 40;
input double   InpLaguerreGamma  = 0.50;
input int      InpMurreyPeriod   = 64;
input int      InpATRPeriod      = 14;
input int      InpRVOLPeriod     = 20;   // Relative Volume Lookback
input int      InpERPeriod       = 10;   // Efficiency Ratio Lookback
input int      InpZScorePeriod   = 20;   // Z-Score Lookback

input group "TSI Settings"
input int      InpTSI_Slow       = 25;   // TSI Slow Period
input int      InpTSI_Fast       = 13;   // TSI Fast Period
input int      InpTSI_Signal     = 13;   // TSI Signal Period

input group "Squeeze Settings"
input int      InpSqueezeLength  = 20;   // Indicators Length
input double   InpBBMult         = 2.0;  // Bollinger Deviation
input double   InpKCMult         = 1.5;  // Keltner Multiplier

//--- Struct for QuantScan 2.0 Data
struct QuantData
  {
   string            timestamp;
   string            symbol;
   double            price;

   // --- H1 Context ---
   double            trend_score;      // DSMA Normalized Score
   double            trend_qual;       // Efficiency Ratio (ER)
   string            zone;             // Murrey Math Zone

   // --- M15 Execution ---
   double            momentum;         // Laguerre RSI
   double            vol_qual;         // Relative Volume (RVOL)
   string            squeeze;          // ON/OFF
   double            z_score;          // Statistical Deviation
   double            vola_regime;      // ATR(5)/ATR(50) Ratio
   string            tsi_dir;          // TSI Direction (BULL/BEAR)
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

// 2. Prepare CSV
   string filename = "QuantScan_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + ".csv";
   StringReplace(filename, ":", "");
   StringReplace(filename, " ", "_");

   int file_handle = FileOpen(filename, FILE_CSV|FILE_WRITE|FILE_ANSI, ";");
   if(file_handle == INVALID_HANDLE)
     {
      Print("Error: Cannot write CSV.");
      return;
     }

// 3. Header (QuantScan 2.0 Format)
   FileWrite(file_handle,
             "TIME", "SYMBOL", "PRICE",
             "TREND_SCORE", "TREND_QUAL", "ZONE", // H1 Context
             "MOMENTUM", "VOL_QUAL", "SQUEEZE", "Z_SCORE", "VOL_REGIME", "TSI_DIR" // M15 Data
            );

// 4. Main Loop
   PrintFormat("Scanning %d symbols...", total_symbols);

   for(int i=0; i<total_symbols; i++)
     {
      string sym = symbols[i];
      StringTrimLeft(sym);
      StringTrimRight(sym);

      QuantData data;
      ZeroMemory(data);

      // Compute
      if(RunQuantAnalysis(sym, data))
        {
         FileWrite(file_handle,
                   data.timestamp,
                   data.symbol,
                   DoubleToString(data.price, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS)),
                   DoubleToString(data.trend_score, 2),
                   DoubleToString(data.trend_qual, 2),
                   data.zone,
                   DoubleToString(data.momentum, 2),
                   DoubleToString(data.vol_qual, 2),
                   data.squeeze,
                   DoubleToString(data.z_score, 2),
                   DoubleToString(data.vola_regime, 2),
                   data.tsi_dir
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
bool RunQuantAnalysis(string sym, QuantData &data)
  {
// --- Common Data ---
   data.timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
   StringReplace(data.timestamp, ".", "."); // Ensure format YYYY.MM.DD
   data.symbol    = sym;
   data.price     = SymbolInfoDouble(sym, SYMBOL_BID);

// =================================================================
// PHASE 1: H1 CONTEXT (Trend, Structure, Quality)
// =================================================================

// Fetch H1 Data
   double h1_o[], h1_h[], h1_l[], h1_c[];
   long   h1_v[];
   datetime h1_t[];
   if(!FetchData(sym, InpTFSlow, 300, h1_t, h1_o, h1_h, h1_l, h1_c, h1_v))
      return false;

// 1. H1 ATR (Normalization Base)
   double h1_atr = Calc_ATR(h1_o, h1_h, h1_l, h1_c, InpATRPeriod);
   if(h1_atr == 0)
      return false;

// 2. Trend Score (DSMA Deviation)
   data.trend_score = Calc_DSMA_Score(h1_o, h1_h, h1_l, h1_c, h1_atr);

// 3. Trend Quality (Kaufman Efficiency Ratio)
   data.trend_qual = Calc_EfficiencyRatio(h1_c, InpERPeriod);

// 4. Zone (Murrey Math)
   data.zone = Calc_MurreyZone(sym, InpTFSlow);


// =================================================================
// PHASE 2: M15 TRIGGER (Momentum, Vol, Stats)
// =================================================================

// Fetch M15 Data
   double m15_o[], m15_h[], m15_l[], m15_c[];
   long   m15_v[];
   datetime m15_t[];
   if(!FetchData(sym, InpTFFast, 300, m15_t, m15_o, m15_h, m15_l, m15_c, m15_v))
      return false;

// 1. Momentum (Laguerre RSI)
   data.momentum = Calc_LaguerreRSI(m15_o, m15_h, m15_l, m15_c);

// 2. Volume Quality (RVOL)
   data.vol_qual = Calc_RVOL(m15_v, InpRVOLPeriod);

// 3. Squeeze (BB inside Keltner)
   data.squeeze = Calc_Squeeze(sym, InpTFFast, m15_o, m15_h, m15_l, m15_c);

// 4. Z-Score (Mean Reversion)
   data.z_score = Calc_ZScore(m15_c, InpZScorePeriod);

// 5. Volatility Regime (Fast/Slow Vola)
   double atr_fast = Calc_ATR(m15_o, m15_h, m15_l, m15_c, 5);
   double atr_slow = Calc_ATR(m15_o, m15_h, m15_l, m15_c, 50);
   if(atr_slow != 0)
      data.vola_regime = atr_fast / atr_slow;
   else
      data.vola_regime = 1.0;

// 6. TSI Direction
   Calc_TSI_Dir(m15_o, m15_h, m15_l, m15_c, data.tsi_dir);

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
//| WRAPPER: RVOL (Relative Volume)                                  |
//+------------------------------------------------------------------+
double Calc_RVOL(const long &vol[], int period)
  {
   int total = ArraySize(vol);
   if(total <= period)
      return 1.0;
   double sum = 0;
   for(int i=1; i<=period; i++)
      sum += (double)vol[total - 1 - i];
   double avg = sum / period;
   if(avg == 0)
      return 0;
   return (double)vol[total-1] / avg;
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
//| WRAPPER: Squeeze (Uses Global Inputs)                            |
//+------------------------------------------------------------------+
string Calc_Squeeze(string sym, ENUM_TIMEFRAMES tf, const double &o[], const double &h[], const double &l[], const double &c[])
  {
   int total = ArraySize(c);

// 1. Calc BB (Uses Inputs)
   CBollingerBandsCalculator bb;
   if(!bb.Init(InpSqueezeLength, InpBBMult, SMA))
      return "ERR";
   double b_ma[], b_up[], b_lo[];
   ArrayResize(b_ma, total);
   ArrayResize(b_up, total);
   ArrayResize(b_lo, total);
   bb.Calculate(total, 0, PRICE_CLOSE, o, h, l, c, b_ma, b_up, b_lo);

// 2. Calc KC (Uses Inputs)
   CKeltnerChannelCalculator kc;
   if(!kc.Init(InpSqueezeLength, SMA, InpSqueezeLength, InpKCMult, ATR_SOURCE_STANDARD))
      return "ERR";
   double k_ma[], k_up[], k_lo[];
   ArrayResize(k_ma, total);
   ArrayResize(k_up, total);
   ArrayResize(k_lo, total);

// Correct call signature
   kc.Calculate(total, 0, o, h, l, c, PRICE_CLOSE, k_ma, k_up, k_lo);

// 3. Logic
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
//| WRAPPER: TSI Direction (Uses Global Inputs)                      |
//+------------------------------------------------------------------+
void Calc_TSI_Dir(const double &o[], const double &h[], const double &l[], const double &c[], string &dir)
  {
   CTSICalculator calc;
// Using Global Inputs
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
