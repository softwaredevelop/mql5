//+------------------------------------------------------------------+
//|                                     SymbolInfoDoubleChecker.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored into a class-based structure
#property description "Checks and displays all DOUBLE properties for the current symbol."

#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Class to check and display symbol properties                     |
//+------------------------------------------------------------------+
class CSymbolPropertyChecker
  {
private:
   CSymbolInfo       m_symbol_info;
   string            m_symbol_name;

   //--- Array of all double properties to check.
   static const ENUM_SYMBOL_INFO_DOUBLE S_DOUBLE_PROPERTIES[];

public:
                     CSymbolPropertyChecker(const string symbol);
   bool              Run(void);

private:
   void              PrintHeader(void);
   void              PrintFooter(void);
   void              PrintProperty(ENUM_SYMBOL_INFO_DOUBLE property_id);
  };

//--- Static member initialization
const ENUM_SYMBOL_INFO_DOUBLE CSymbolPropertyChecker::S_DOUBLE_PROPERTIES[] =
  {
   SYMBOL_BID, SYMBOL_BIDHIGH, SYMBOL_BIDLOW, SYMBOL_ASK, SYMBOL_ASKHIGH,
   SYMBOL_ASKLOW, SYMBOL_LAST, SYMBOL_LASTHIGH, SYMBOL_LASTLOW,
   SYMBOL_VOLUME_REAL, SYMBOL_VOLUMEHIGH_REAL, SYMBOL_VOLUMELOW_REAL,
   SYMBOL_OPTION_STRIKE, SYMBOL_POINT, SYMBOL_TRADE_TICK_VALUE,
   SYMBOL_TRADE_TICK_VALUE_PROFIT, SYMBOL_TRADE_TICK_VALUE_LOSS,
   SYMBOL_TRADE_TICK_SIZE, SYMBOL_TRADE_CONTRACT_SIZE,
   SYMBOL_TRADE_ACCRUED_INTEREST, SYMBOL_TRADE_FACE_VALUE,
   SYMBOL_TRADE_LIQUIDITY_RATE, SYMBOL_VOLUME_MIN, SYMBOL_VOLUME_MAX,
   SYMBOL_VOLUME_STEP, SYMBOL_VOLUME_LIMIT, SYMBOL_SWAP_LONG,
   SYMBOL_SWAP_SHORT, SYMBOL_SWAP_SUNDAY, SYMBOL_SWAP_MONDAY, SYMBOL_SWAP_TUESDAY,
   SYMBOL_SWAP_WEDNESDAY, SYMBOL_SWAP_THURSDAY, SYMBOL_SWAP_FRIDAY,
   SYMBOL_SWAP_SATURDAY, SYMBOL_MARGIN_INITIAL, SYMBOL_MARGIN_MAINTENANCE,
   SYMBOL_SESSION_VOLUME, SYMBOL_SESSION_TURNOVER, SYMBOL_SESSION_INTEREST,
   SYMBOL_SESSION_BUY_ORDERS_VOLUME, SYMBOL_SESSION_SELL_ORDERS_VOLUME,
   SYMBOL_SESSION_OPEN, SYMBOL_SESSION_CLOSE, SYMBOL_SESSION_AW,
   SYMBOL_SESSION_PRICE_SETTLEMENT, SYMBOL_SESSION_PRICE_LIMIT_MIN,
   SYMBOL_SESSION_PRICE_LIMIT_MAX, SYMBOL_MARGIN_HEDGED, SYMBOL_PRICE_CHANGE,
   SYMBOL_PRICE_VOLATILITY, SYMBOL_PRICE_THEORETICAL, SYMBOL_PRICE_DELTA,
   SYMBOL_PRICE_THETA, SYMBOL_PRICE_GAMMA, SYMBOL_PRICE_VEGA,
   SYMBOL_PRICE_RHO, SYMBOL_PRICE_OMEGA, SYMBOL_PRICE_SENSITIVITY
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSymbolPropertyChecker::CSymbolPropertyChecker(const string symbol) : m_symbol_name(symbol)
  {
// Initialization of m_symbol_info is handled in Run()
  }

//+------------------------------------------------------------------+
//| Runs the property check process                                  |
//+------------------------------------------------------------------+
bool CSymbolPropertyChecker::Run(void)
  {
   if(!m_symbol_info.Name(m_symbol_name))
     {
      PrintFormat("Error: Symbol '%s' not found or not available in Market Watch.", m_symbol_name);
      return false;
     }

   PrintHeader();

   for(int i = 0; i < ArraySize(S_DOUBLE_PROPERTIES); i++)
     {
      PrintProperty(S_DOUBLE_PROPERTIES[i]);
     }

   PrintFooter();
   return true;
  }

//+------------------------------------------------------------------+
//| Prints a single property's status and value                      |
//+------------------------------------------------------------------+
void CSymbolPropertyChecker::PrintProperty(ENUM_SYMBOL_INFO_DOUBLE property_id)
  {
   double value;
   string result_str;
   string property_name = EnumToString(property_id);

   ResetLastError();
   bool success = m_symbol_info.InfoDouble(property_id, value);
   int error = GetLastError();

   if(success)
     {
      result_str = StringFormat("%-35s | Status: SUPPORTED | Value: %g",
                                property_name,
                                value);
     }
   else
     {
      result_str = StringFormat("%-35s | Status: FAILED    | Error: %d",
                                property_name,
                                error);
     }
   Print(result_str);
  }

//+------------------------------------------------------------------+
//| Prints the header for the output                                 |
//+------------------------------------------------------------------+
void CSymbolPropertyChecker::PrintHeader(void)
  {
   Print("--- Symbol Property Checker Started ---");
   PrintFormat("Checking symbol: %s", m_symbol_name);
   Print("------------------------------------------------------------------");
  }

//+------------------------------------------------------------------+
//| Prints the footer for the output                                 |
//+------------------------------------------------------------------+
void CSymbolPropertyChecker::PrintFooter(void)
  {
   Print("------------------------------------------------------------------");
   Print("--- Check Completed ---");
  }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   CSymbolPropertyChecker checker(_Symbol);
   checker.Run();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
