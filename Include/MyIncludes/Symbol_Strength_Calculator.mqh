//+------------------------------------------------------------------+
//|                                   Symbol_Strength_Calculator.mqh |
//|      VERSION 1.20: Added symbol existence check.                 |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CSymbolStrengthCalculator
  {
private:
   int               m_period;
   ENUM_TIMEFRAMES   m_timeframe;
   string            m_symbols[];
   int               m_symbol_count;

   double            GetROC(string symbol, int index);

public:
                     CSymbolStrengthCalculator(void) : m_symbol_count(0) {};
                    ~CSymbolStrengthCalculator(void) {};

   bool              Init(int period, ENUM_TIMEFRAMES tf, const string &symbols[]);
   void              CalculateStep(int bar_index, double &strengths[]);
   int               GetCount() { return m_symbol_count; }

   bool              IsDataReady(void);
  };

//+------------------------------------------------------------------+
bool CSymbolStrengthCalculator::Init(int period, ENUM_TIMEFRAMES tf, const string &symbols[])
  {
   m_period = period;
   m_timeframe = tf;

   m_symbol_count = ArraySize(symbols);
   ArrayResize(m_symbols, m_symbol_count);

   for(int i=0; i<m_symbol_count; i++)
     {
      string sym = symbols[i];

      // Skip empty inputs
      if(sym == "")
        {
         m_symbols[i] = "";
         continue;
        }

      // Check if symbol exists in Market Watch or Database
      if(!SymbolInfoInteger(sym, SYMBOL_SELECT))
        {
         if(GetLastError() == 4106) // ERR_UNKNOWN_SYMBOL
           {
            // Try to select it (maybe it exists but not selected)
            if(!SymbolSelect(sym, true))
              {
               Print("Global Market Strength Error: Symbol '", sym, "' not found! Please check spelling.");
               m_symbols[i] = ""; // Disable this slot to prevent blocking
               continue;
              }
           }
         else
           {
            // Try to select anyway
            if(!SymbolSelect(sym, true))
              {
               Print("Global Market Strength Error: Symbol '", sym, "' not found! Please check spelling.");
               m_symbols[i] = ""; // Disable this slot
               continue;
              }
           }
        }

      // If we are here, symbol exists and is selected
      m_symbols[i] = sym;
      // Force sync
      iTime(m_symbols[i], m_timeframe, 0);
     }
   return true;
  }

//+------------------------------------------------------------------+
bool CSymbolStrengthCalculator::IsDataReady(void)
  {
   for(int i=0; i<m_symbol_count; i++)
     {
      if(m_symbols[i] == "")
         continue; // Skip invalid/empty symbols

      // Check if bars are synchronized
      if(!SeriesInfoInteger(m_symbols[i], m_timeframe, SERIES_SYNCHRONIZED))
         return false;

      // Check if enough bars are available
      if(SeriesInfoInteger(m_symbols[i], m_timeframe, SERIES_BARS_COUNT) < m_period + 10)
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
double CSymbolStrengthCalculator::GetROC(string symbol, int index)
  {
   if(symbol == "")
      return EMPTY_VALUE;

   double close_curr[1], close_prev[1];

   if(CopyClose(symbol, m_timeframe, index, 1, close_curr) <= 0)
      return EMPTY_VALUE;
   if(CopyClose(symbol, m_timeframe, index + m_period, 1, close_prev) <= 0)
      return EMPTY_VALUE;

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
void CSymbolStrengthCalculator::CalculateStep(int bar_index, double &strengths[])
  {
   ArrayResize(strengths, m_symbol_count);
   ArrayInitialize(strengths, EMPTY_VALUE);

   for(int i = 0; i < m_symbol_count; i++)
     {
      if(m_symbols[i] != "")
         strengths[i] = GetROC(m_symbols[i], bar_index);
     }
  }
//+------------------------------------------------------------------+
