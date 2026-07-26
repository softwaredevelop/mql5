//+------------------------------------------------------------------+
//|                                  PairsTrading_Check_Symbols.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Standard diagnostic utility for pairs trading symbols
#property description "QuantScan Pairs Trading Broker Symbol Diagnostic Script"
#property script_show_inputs

//--- Predefined common symbol candidates to search for
string g_candidates[] =
  {
   "UKOIL", "BRENT", "UKOil", "XBRUSD", "COCOA",
   "USOIL", "WTI", "USOil", "XTIUSD", "CL",
   "US500", "SPY", "USSPX500", "S&P500",
   "US100", "QQQ", "USNDAQ100", "NASDAQ100",
   "DE40", "GER40", "DAX40",
   "EU50", "ESTX50", "EUR50",
   "XAUUSD", "GOLD",
   "XAGUSD", "SILVER",
   "EURUSD", "GBPUSD", "AUDUSD", "NZDUSD", "USDJPY", "USDCHF"
  };

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("====================================================================");
   Print("         PAIRS TRADING COINTEGRATION SYMBOL DIAGNOSTIC REPORT       ");
   Print("====================================================================");
   PrintFormat("Active Broker: %s", TerminalInfoString(TERMINAL_COMPANY));
   Print("Scanning broker's market database for valid pairs trading candidates...");
   Print("--------------------------------------------------------------------");

   int candidates_total = ArraySize(g_candidates);
   int found_count = 0;

   for(int i = 0; i < candidates_total; i++)
     {
      string target = g_candidates[i];
      bool is_custom = false;

      // Check if symbol exists in the broker's database
      if(SymbolExist(target, is_custom))
        {
         found_count++;
         bool is_selected = (bool)SymbolInfoInteger(target, SYMBOL_SELECT);
         double bid = SymbolInfoDouble(target, SYMBOL_BID);
         string path = SymbolInfoString(target, SYMBOL_PATH);

         PrintFormat("MATCH FOUND: Symbol: '%s' | Selected in Market Watch: %s | Current Bid: %f | Path: %s",
                     target, (is_selected ? "YES" : "NO"), bid, path);
        }
     }

   Print("--------------------------------------------------------------------");
   PrintFormat("Scan Complete. Found %d valid candidates out of %d tested.", found_count, candidates_total);
   Print("====================================================================");

   string summary_msg = StringFormat("Diagnostic Complete!\nFound %d valid pairs trading symbols on your broker.\nCheck the Experts tab for the full report.", found_count);
   Alert(summary_msg);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
