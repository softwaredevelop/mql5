//+------------------------------------------------------------------+
//|                                     SymbolInfoIntegerChecker.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.01"
#property description "Checks and displays all INTEGER properties for the current symbol."

#include <Trade\SymbolInfo.mqh>
//--- MODIFICATION: Including our new helper file
#include "SymbolInfoDescriptions.mqh"

//--- Array of all integer properties to check
const ENUM_SYMBOL_INFO_INTEGER G_INT_PROPERTIES[] =
  {
   SYMBOL_SUBSCRIPTION_DELAY, SYMBOL_SECTOR, SYMBOL_INDUSTRY, SYMBOL_CUSTOM,
   SYMBOL_BACKGROUND_COLOR, SYMBOL_CHART_MODE, SYMBOL_EXIST, SYMBOL_SELECT,
   SYMBOL_VISIBLE, SYMBOL_SESSION_DEALS, SYMBOL_SESSION_BUY_ORDERS,
   SYMBOL_SESSION_SELL_ORDERS, SYMBOL_VOLUME, SYMBOL_VOLUMEHIGH,
   SYMBOL_VOLUMELOW, SYMBOL_TIME, SYMBOL_TIME_MSC, SYMBOL_DIGITS,
   SYMBOL_SPREAD_FLOAT, SYMBOL_SPREAD, SYMBOL_TICKS_BOOKDEPTH,
   SYMBOL_TRADE_CALC_MODE, SYMBOL_TRADE_MODE, SYMBOL_START_TIME,
   SYMBOL_EXPIRATION_TIME, SYMBOL_TRADE_STOPS_LEVEL,
   SYMBOL_TRADE_FREEZE_LEVEL, SYMBOL_TRADE_EXEMODE, SYMBOL_SWAP_MODE,
   SYMBOL_SWAP_ROLLOVER3DAYS, SYMBOL_MARGIN_HEDGED_USE_LEG,
   SYMBOL_EXPIRATION_MODE, SYMBOL_FILLING_MODE, SYMBOL_ORDER_MODE,
   SYMBOL_ORDER_GTC_MODE, SYMBOL_OPTION_MODE, SYMBOL_OPTION_RIGHT
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
// Refresh data to get the latest values
   m_symbol_info.Refresh();

   Print("--- Symbol Property Checker Started ---");
   PrintFormat("Checking symbol: %s", symbol);
   Print("------------------------------------------------------------------");

   long value;
   string result_str;

   for(int i = 0; i < ArraySize(G_INT_PROPERTIES); i++)
     {
      ResetLastError();
      bool success = m_symbol_info.InfoInteger(G_INT_PROPERTIES[i], value);
      int error = GetLastError();

      string property_name = EnumToString(G_INT_PROPERTIES[i]);
      string property_name_padded = StringFormat("%-35s", property_name);

      if(success)
        {
         //--- MODIFICATION: Calling the helper function to get the formatted value
         string display_value = FormatIntegerValue(m_symbol_info, G_INT_PROPERTIES[i], value);

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
