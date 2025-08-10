//+------------------------------------------------------------------+
//|                                      SymbolInfoDoubleChecker.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.02" // Version updated to reflect fixes
#property description "Checks and displays all DOUBLE properties for the current symbol."

#include <Trade\SymbolInfo.mqh>

//--- Array of all double properties to check.
const ENUM_SYMBOL_INFO_DOUBLE G_DOUBLE_PROPERTIES[] =
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
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   string symbol = _Symbol;

// Initialize CSymbolInfo. The constructor is parameterless.
// We must call .Name() to set the symbol.
   CSymbolInfo m_symbol_info;
   if(!m_symbol_info.Name(symbol))
     {
      PrintFormat("Error: Symbol '%s' not found or not available in Market Watch.", symbol);
      return;
     }

   Print("--- Symbol Property Checker Started ---");
   PrintFormat("Checking symbol: %s", symbol);
   Print("------------------------------------------------------------------");

   double value;
   string result_str;

   for(int i = 0; i < ArraySize(G_DOUBLE_PROPERTIES); i++)
     {
      ResetLastError();
      bool success = m_symbol_info.InfoDouble(G_DOUBLE_PROPERTIES[i], value);
      int error = GetLastError();

      // --- FIX: Using StringFormat with padding for alignment ---
      // The "%-35s" specifier pads the string to 35 characters, left-aligned.
      string property_name = EnumToString(G_DOUBLE_PROPERTIES[i]);

      if(success)
        {
         // The "%g" specifier provides a general, clean format for double values.
         result_str = StringFormat("%-35s | Status: SUPPORTED | Value: %g",
                                   property_name,
                                   value);
         Print(result_str);
        }
      else
        {
         result_str = StringFormat("%-35s | Status: FAILED    | Error: %d",
                                   property_name,
                                   error);
         Print(result_str);
        }
     }
   Print("------------------------------------------------------------------");
   Print("--- Check Completed ---");
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
