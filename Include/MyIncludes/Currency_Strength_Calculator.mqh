//+------------------------------------------------------------------+
//|                                 Currency_Strength_Calculator.mqh |
//|      Engine for calculating relative currency strength.          |
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
  };

//+------------------------------------------------------------------+
bool CCurrencyStrengthCalculator::Init(int period, ENUM_TIMEFRAMES tf)
  {
   m_period = period;
   m_timeframe = tf;
   return true;
  }

//+------------------------------------------------------------------+
double CCurrencyStrengthCalculator::GetROC(string symbol, int index)
  {
// We need Close[index] and Close[index + period]
   double close_curr[1], close_prev[1];

// Check if symbol is available in Market Watch
   if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
      SymbolSelect(symbol, true);

   if(CopyClose(symbol, m_timeframe, index, 1, close_curr) <= 0)
      return 0.0;
   if(CopyClose(symbol, m_timeframe, index + m_period, 1, close_prev) <= 0)
      return 0.0;

   if(close_prev[0] == 0)
      return 0.0;

   return ((close_curr[0] - close_prev[0]) / close_prev[0]) * 100.0;
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

// Optional: Normalize or smooth here if needed
  }
//+------------------------------------------------------------------+
