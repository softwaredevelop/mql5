//+------------------------------------------------------------------+
//|                                     SymbolInfoStringChecker.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored into a class-based structure
#property description "Checks and displays all STRING properties for the current symbol."

#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Class to check and display STRING symbol properties              |
//+------------------------------------------------------------------+
class CSymbolStringPropertyChecker
  {
private:
   CSymbolInfo       m_symbol_info;
   string            m_symbol_name;

   //--- Array of all string properties to check.
   static const ENUM_SYMBOL_INFO_STRING S_STRING_PROPERTIES[];

public:
                     CSymbolStringPropertyChecker(const string symbol);
   bool              Run(void);

private:
   void              PrintHeader(void);
   void              PrintFooter(void);
   void              PrintProperty(ENUM_SYMBOL_INFO_STRING property_id);
   string            FormatValue(string value);
  };

//--- Static member initialization
const ENUM_SYMBOL_INFO_STRING CSymbolStringPropertyChecker::S_STRING_PROPERTIES[] =
  {
   SYMBOL_BASIS, SYMBOL_CATEGORY, SYMBOL_COUNTRY, SYMBOL_SECTOR_NAME,
   SYMBOL_INDUSTRY_NAME, SYMBOL_CURRENCY_BASE, SYMBOL_CURRENCY_PROFIT,
   SYMBOL_CURRENCY_MARGIN, SYMBOL_BANK, SYMBOL_DESCRIPTION,
   SYMBOL_EXCHANGE, SYMBOL_FORMULA, SYMBOL_ISIN, SYMBOL_PAGE, SYMBOL_PATH
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSymbolStringPropertyChecker::CSymbolStringPropertyChecker(const string symbol) : m_symbol_name(symbol)
  {
  }

//+------------------------------------------------------------------+
//| Runs the property check process                                  |
//+------------------------------------------------------------------+
bool CSymbolStringPropertyChecker::Run(void)
  {
   if(!m_symbol_info.Name(m_symbol_name))
     {
      PrintFormat("Error: Symbol '%s' not found or not available in Market Watch.", m_symbol_name);
      return false;
     }
   m_symbol_info.Refresh();

   PrintHeader();

   for(int i = 0; i < ArraySize(S_STRING_PROPERTIES); i++)
     {
      PrintProperty(S_STRING_PROPERTIES[i]);
     }

   PrintFooter();
   return true;
  }

//+------------------------------------------------------------------+
//| Prints a single property's status and value                      |
//+------------------------------------------------------------------+
void CSymbolStringPropertyChecker::PrintProperty(ENUM_SYMBOL_INFO_STRING property_id)
  {
   string value;
   string result_str;
   string property_name = EnumToString(property_id);

   ResetLastError();
   if(m_symbol_info.InfoString(property_id, value))
     {
      result_str = StringFormat("%-35s | Status: SUPPORTED | Value: %s",
                                property_name,
                                FormatValue(value));
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
//| Formats a STRING property value into a readable string           |
//+------------------------------------------------------------------+
string CSymbolStringPropertyChecker::FormatValue(string value)
  {
   if(value == "")
     {
      return("<EMPTY>");
     }
   else
     {
      return("'" + value + "'");
     }
  }

//+------------------------------------------------------------------+
//| Prints the header for the output                                 |
//+------------------------------------------------------------------+
void CSymbolStringPropertyChecker::PrintHeader(void)
  {
   Print("--- Symbol String Property Checker Started ---");
   PrintFormat("Checking symbol: %s", m_symbol_name);
   Print("------------------------------------------------------------------");
  }

//+------------------------------------------------------------------+
//| Prints the footer for the output                                 |
//+------------------------------------------------------------------+
void CSymbolStringPropertyChecker::PrintFooter(void)
  {
   Print("------------------------------------------------------------------");
   Print("--- Check Completed ---");
  }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   CSymbolStringPropertyChecker checker(_Symbol);
   checker.Run();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
