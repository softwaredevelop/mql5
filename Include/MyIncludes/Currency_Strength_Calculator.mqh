//+------------------------------------------------------------------+
//|                                 Currency_Strength_Calculator.mqh |
//|      VERSION 1.10: Robust data handling and synchronization.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

//--- List of 8 Major Currencies
string g_currencies[8] = {"USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "NZD"};

//--- List of 28 Major Pairs to monitor
string g_pairs[28] =
  {
   "EURUSD", "GBPUSD", "AUDUSD", "NZDUSD", "USDCAD", "USDCHF", "USDJPY",
   "EURGBP", "EURAUD", "EURNZD", "EURCAD", "EURCHF", "EURJPY",
   "GBPAUD", "GBPNZD", "GBPCAD", "GBPCHF", "GBPJPY",
   "AUDNZD", "AUDCAD", "AUDCHF", "AUDJPY",
   "NZDCAD", "NZDCHF", "NZDJPY",
   "CADCHF", "CADJPY",
   "CHFJPY"
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CCurrencyStrengthCalculator
  {
private:
   int               m_period;
   ENUM_TIMEFRAMES   m_timeframe;

   //--- Helper to get ROC of a symbol
   double            GetROC(string symbol, int index);

public:
                     CCurrencyStrengthCalculator(void) {};
                    ~CCurrencyStrengthCalculator(void) {};

   bool              Init(int period, ENUM_TIMEFRAMES tf);

   //--- Main calculation: Fills the strength array [8] for a specific bar index
   void              CalculateStep(int bar_index, double &strengths[]);

   //--- NEW: Check if data is ready for all pairs
   bool              IsDataReady(void);
  };

//+------------------------------------------------------------------+
bool CCurrencyStrengthCalculator::Init(int period, ENUM_TIMEFRAMES tf)
  {
   m_period = period;
   m_timeframe = tf;

// Ensure all symbols are selected
   for(int i=0; i<28; i++)
     {
      if(!SymbolInfoInteger(g_pairs[i], SYMBOL_SELECT))
         SymbolSelect(g_pairs[i], true);
      // Force sync
      iTime(g_pairs[i], m_timeframe, 0);
     }
   return true;
  }

//+------------------------------------------------------------------+
bool CCurrencyStrengthCalculator::IsDataReady(void)
  {
   for(int i=0; i<28; i++)
     {
      // Check if bars are synchronized
      if(!SeriesInfoInteger(g_pairs[i], m_timeframe, SERIES_SYNCHRONIZED))
         return false;

      // Check if enough bars are available
      if(SeriesInfoInteger(g_pairs[i], m_timeframe, SERIES_BARS_COUNT) < m_period + 10)
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
double CCurrencyStrengthCalculator::GetROC(string symbol, int index)
  {
   double close_curr[1], close_prev[1];

   if(CopyClose(symbol, m_timeframe, index, 1, close_curr) <= 0)
      return EMPTY_VALUE;
   if(CopyClose(symbol, m_timeframe, index + m_period, 1, close_prev) <= 0)
      return EMPTY_VALUE;

// Robust check
   if(close_prev[0] <= 0.0000001 || !MathIsValidNumber(close_prev[0]))
      return EMPTY_VALUE;
   if(close_curr[0] <= 0.0000001 || !MathIsValidNumber(close_curr[0]))
      return EMPTY_VALUE;

   double roc = ((close_curr[0] - close_prev[0]) / close_prev[0]) * 100.0;

   if(!MathIsValidNumber(roc))
      return EMPTY_VALUE;

   return roc;
  }

//+------------------------------------------------------------------+
void CCurrencyStrengthCalculator::CalculateStep(int bar_index, double &strengths[])
  {
   ArrayInitialize(strengths, 0.0); // Reset [0..7]

   for(int i = 0; i < 28; i++)
     {
      string symbol = g_pairs[i];
      string base = StringSubstr(symbol, 0, 3);
      string quote = StringSubstr(symbol, 3, 3);

      double roc = GetROC(symbol, bar_index);

      if(roc == EMPTY_VALUE)
         continue; // Skip invalid pairs

      // Find indices
      int base_idx = -1, quote_idx = -1;
      for(int k=0; k<8; k++)
        {
         if(g_currencies[k] == base)
            base_idx = k;
         if(g_currencies[k] == quote)
            quote_idx = k;
        }

      if(base_idx != -1 && quote_idx != -1)
        {
         // If Pair goes UP, Base is Stronger, Quote is Weaker
         strengths[base_idx] += roc;
         strengths[quote_idx] -= roc;
        }
     }
  }
//+------------------------------------------------------------------+
