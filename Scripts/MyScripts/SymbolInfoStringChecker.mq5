//+------------------------------------------------------------------+
//|                                      SymbolInfoStringChecker.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.01"
#property description "Checks and displays all STRING properties for the current symbol."

#include <Trade\SymbolInfo.mqh>

//--- Array of all string properties to check.
const ENUM_SYMBOL_INFO_STRING G_STRING_PROPERTIES[] =
  {
   SYMBOL_BASIS,
   SYMBOL_CATEGORY,
   SYMBOL_COUNTRY,
   SYMBOL_SECTOR_NAME,
   SYMBOL_INDUSTRY_NAME,
   SYMBOL_CURRENCY_BASE,
   SYMBOL_CURRENCY_PROFIT,
   SYMBOL_CURRENCY_MARGIN,
   SYMBOL_BANK,
   SYMBOL_DESCRIPTION,
   SYMBOL_EXCHANGE,
   SYMBOL_FORMULA,
   SYMBOL_ISIN,
   SYMBOL_PAGE,
   SYMBOL_PATH
  };

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   string symbol = _Symbol;
   CSymbolInfo m_symbol_info;

   if(!m_symbol_info.Name(symbol))
     {
      PrintFormat("Error: Failed to set symbol '%s'.", symbol);
      return;
     }
   m_symbol_info.Refresh();

   Print("--- Symbol Property Checker Started ---");
   PrintFormat("Checking symbol: %s", symbol);
   Print("------------------------------------------------------------------");

   string value;
   string result_str;

   for(int i = 0; i < ArraySize(G_STRING_PROPERTIES); i++)
     {
      ResetLastError();
      bool success = m_symbol_info.InfoString(G_STRING_PROPERTIES[i], value);
      int error = GetLastError();

      // Use StringFormat with padding for consistent alignment
      string property_name = EnumToString(G_STRING_PROPERTIES[i]);
      string property_name_padded = StringFormat("%-35s", property_name);

      if(success)
        {
         string display_value;
         if(value == "")
           {
            // Indicate that the property is supported but the value is empty
            display_value = "<EMPTY>";
           }
         else
           {
            // Enclose the value in single quotes for clarity
            display_value = "'" + value + "'";
           }

         result_str = StringFormat("%s | Status: SUPPORTED | Value: %s",
                                   property_name_padded,
                                   display_value);
         Print(result_str);
        }
      else
        {
         result_str = StringFormat("%s | Status: FAILED    | Error: %d",
                                   property_name_padded,
                                   error);
         Print(result_str);
        }
     }
   Print("------------------------------------------------------------------");
   Print("--- Check Completed ---");
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
