//+------------------------------------------------------------------+
//|                                     SymbolInfoIntegerChecker.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored into a class-based structure
#property description "Checks and displays all INTEGER properties for the current symbol."

#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Class to check and display INTEGER symbol properties             |
//+------------------------------------------------------------------+
class CSymbolIntegerPropertyChecker
  {
private:
   CSymbolInfo       m_symbol_info;
   string            m_symbol_name;

   //--- Array of all integer properties to check.
   static const ENUM_SYMBOL_INFO_INTEGER S_INT_PROPERTIES[];

public:
                     CSymbolIntegerPropertyChecker(const string symbol);
   bool              Run(void);

private:
   void              PrintHeader(void);
   void              PrintFooter(void);
   void              PrintProperty(ENUM_SYMBOL_INFO_INTEGER property_id);
   string            FormatValue(ENUM_SYMBOL_INFO_INTEGER property_id, long value);
  };

//--- Static member initialization
const ENUM_SYMBOL_INFO_INTEGER CSymbolIntegerPropertyChecker::S_INT_PROPERTIES[] =
  {
   SYMBOL_CUSTOM, SYMBOL_CHART_MODE, SYMBOL_EXIST, SYMBOL_SELECT,
   SYMBOL_VISIBLE, SYMBOL_SESSION_DEALS, SYMBOL_SESSION_BUY_ORDERS,
   SYMBOL_SESSION_SELL_ORDERS, SYMBOL_VOLUME, SYMBOL_VOLUMEHIGH,
   SYMBOL_VOLUMELOW, SYMBOL_TIME, SYMBOL_TIME_MSC, SYMBOL_DIGITS,
   SYMBOL_SPREAD_FLOAT, SYMBOL_SPREAD, SYMBOL_TICKS_BOOKDEPTH,
   SYMBOL_TRADE_CALC_MODE, SYMBOL_TRADE_MODE, SYMBOL_START_TIME,
   SYMBOL_EXPIRATION_TIME, SYMBOL_TRADE_STOPS_LEVEL,
   SYMBOL_TRADE_FREEZE_LEVEL, SYMBOL_TRADE_EXEMODE, SYMBOL_SWAP_MODE,
   SYMBOL_SWAP_ROLLOVER3DAYS, SYMBOL_EXPIRATION_MODE,
   SYMBOL_FILLING_MODE, SYMBOL_ORDER_MODE, SYMBOL_ORDER_GTC_MODE,
   SYMBOL_OPTION_MODE, SYMBOL_OPTION_RIGHT, SYMBOL_SECTOR, SYMBOL_INDUSTRY
// SYMBOL_SUBSCRIPTION_DELAY, SYMBOL_BACKGROUND_COLOR are obsolete
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSymbolIntegerPropertyChecker::CSymbolIntegerPropertyChecker(const string symbol) : m_symbol_name(symbol)
  {
  }

//+------------------------------------------------------------------+
//| Runs the property check process                                  |
//+------------------------------------------------------------------+
bool CSymbolIntegerPropertyChecker::Run(void)
  {
   if(!m_symbol_info.Name(m_symbol_name))
     {
      PrintFormat("Error: Symbol '%s' not found or not available in Market Watch.", m_symbol_name);
      return false;
     }
   m_symbol_info.Refresh();

   PrintHeader();

   for(int i = 0; i < ArraySize(S_INT_PROPERTIES); i++)
     {
      PrintProperty(S_INT_PROPERTIES[i]);
     }

   PrintFooter();
   return true;
  }

//+------------------------------------------------------------------+
//| Prints a single property's status and value                      |
//+------------------------------------------------------------------+
void CSymbolIntegerPropertyChecker::PrintProperty(ENUM_SYMBOL_INFO_INTEGER property_id)
  {
   long value;
   string result_str;
   string property_name = EnumToString(property_id);

   ResetLastError();
   if(m_symbol_info.InfoInteger(property_id, value))
     {
      result_str = StringFormat("%-35s | Status: SUPPORTED | Value: %s",
                                property_name,
                                FormatValue(property_id, value));
     }
   else
     {
      result_str = StringFormat("%-35s | Status: FAILED    | Error: %d",
                                property_name,
                                GetLastError());
     }
   Print(result_str);
  }

//+------------------------------------------------------------------+
//| Formats an INTEGER property value into a readable string         |
//+------------------------------------------------------------------+
string CSymbolIntegerPropertyChecker::FormatValue(ENUM_SYMBOL_INFO_INTEGER property_id, long value)
  {
   switch(property_id)
     {
      // Descriptions from CSymbolInfo
      case SYMBOL_TRADE_CALC_MODE:
         return(m_symbol_info.TradeCalcModeDescription());
      case SYMBOL_TRADE_MODE:
         return(m_symbol_info.TradeModeDescription());
      case SYMBOL_TRADE_EXEMODE:
         return(m_symbol_info.TradeExecutionDescription());
      case SYMBOL_SWAP_MODE:
         return(m_symbol_info.SwapModeDescription());
      case SYMBOL_SWAP_ROLLOVER3DAYS:
         return(m_symbol_info.SwapRollover3daysDescription());
      // Datetimes
      case SYMBOL_START_TIME:
      case SYMBOL_EXPIRATION_TIME:
      case SYMBOL_TIME:
         return(TimeToString((datetime)value, TIME_DATE | TIME_SECONDS));
      case SYMBOL_TIME_MSC:
        {
         datetime seconds_part = (datetime)(value / 1000);
         long milliseconds_part = value % 1000;
         return(StringFormat("%s.%03d", TimeToString(seconds_part, TIME_DATE | TIME_SECONDS), milliseconds_part));
        }
      // Bools
      case SYMBOL_CUSTOM:
      case SYMBOL_EXIST:
      case SYMBOL_SELECT:
      case SYMBOL_VISIBLE:
      case SYMBOL_SPREAD_FLOAT:
         return((bool)value ? "true" : "false");
      // Default long to string conversion
      default:
         return((string)value);
     }
  }

//+------------------------------------------------------------------+
//| Prints the header for the output                                 |
//+------------------------------------------------------------------+
void CSymbolIntegerPropertyChecker::PrintHeader(void)
  {
   Print("--- Symbol Integer Property Checker Started ---");
   PrintFormat("Checking symbol: %s", m_symbol_name);
   Print("------------------------------------------------------------------");
  }

//+------------------------------------------------------------------+
//| Prints the footer for the output                                 |
//+------------------------------------------------------------------+
void CSymbolIntegerPropertyChecker::PrintFooter(void)
  {
   Print("------------------------------------------------------------------");
   Print("--- Check Completed ---");
  }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   CSymbolIntegerPropertyChecker checker(_Symbol);
   checker.Run();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
