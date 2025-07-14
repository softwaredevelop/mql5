//+------------------------------------------------------------------+
//|                                           SymbolScannerPanel.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs // Show input parameters dialog on start

#include <Trade\SymbolInfo.mqh> // For CSymbolInfo class

// --- Input Parameters for Filtering ---
input string   Filter_Name_Contains = "";     // Filter: Symbol name contains (empty = no filter)
input bool     Filter_Only_Selected_In_MarketWatch = true; // Filter: Only symbols selected in Market Watch

input double   Filter_Min_Volume_Min = 0.0;   // Filter: Minimum allowed minimum volume
input double   Filter_Max_Volume_Min = 1000000.0; // Filter: Maximum allowed minimum volume (e.g., 1,000,000 lots)

input double   Filter_Min_Volume_Step = 0.0;  // Filter: Minimum allowed volume step
input double   Filter_Max_Volume_Step = 1000000.0; // Filter: Maximum allowed volume step

input bool     Filter_Only_ETFs = false;      // Filter: Only Exchange Traded Funds
input bool     Filter_Only_Extended_Hours = false; // Filter: Only symbols with "Extended Hours" in description
input string   Extended_Hours_Keyword = "(Extended Hours)"; // Keyword to identify extended hours symbols

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("--- Symbol Scanner Panel Started ---");
   PrintFormat("Filter Criteria:");
   PrintFormat("  Name Contains: '%s'", Filter_Name_Contains);
   PrintFormat("  Only Market Watch Selected: %s", Filter_Only_Selected_In_MarketWatch ? "Yes" : "No");
   PrintFormat("  Min Volume (Min): %.2f - %.2f", Filter_Min_Volume_Min, Filter_Max_Volume_Min);
   PrintFormat("  Volume Step: %.2f - %.2f", Filter_Min_Volume_Step, Filter_Max_Volume_Step);
   PrintFormat("  Only ETFs: %s", Filter_Only_ETFs ? "Yes" : "No");
   PrintFormat("  Only Extended Hours: %s (Keyword: '%s')", Filter_Only_Extended_Hours ? "Yes" : "No", Extended_Hours_Keyword);
   Print("---------------------------------");

   int total_symbols = 0;
   if(Filter_Only_Selected_In_MarketWatch)
     {
      total_symbols = SymbolsTotal(true); // Count only selected symbols
     }
   else
     {
      total_symbols = SymbolsTotal(false); // Count all available symbols on server
     }

   if(total_symbols == 0)
     {
      Print("No symbols found based on Market Watch selection.");
      return;
     }

   int found_count = 0;

// Print header for the results table
   PrintFormat("%-15s | %-8s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s",
               "Symbol", "Point", "TickValue", "TV_Profit", "TV_Loss", "TickSize", "Vol_Min", "Vol_Step", "Swap_Long", "Swap_Short");
   Print("--------------------------------------------------------------------------------------------------------------------");

// Iterate through all symbols
   for(int i = 0; i < total_symbols; i++)
     {
      string symbol_name;
      if(Filter_Only_Selected_In_MarketWatch)
        {
         symbol_name = SymbolName(i, true);
        }
      else
        {
         symbol_name = SymbolName(i, false);
        }

      CSymbolInfo m_symbol_info; // Instantiate CSymbolInfo object for current symbol

      // Initialize CSymbolInfo object with the symbol. This also calls SymbolSelect.
      if(!m_symbol_info.Name(symbol_name))
        {
         PrintFormat("Error: Failed to initialize CSymbolInfo for symbol '%s'. Error: %d", symbol_name, GetLastError());
         continue; // Skip to next symbol
        }

      // Refresh cached data for the symbol (important for some properties)
      if(!m_symbol_info.Refresh())
        {
         PrintFormat("Error: Failed to refresh symbol data for '%s'. Error: %d", symbol_name, GetLastError());
         continue; // Skip to next symbol
        }

      // --- Retrieve all necessary properties for display and filtering ---
      // Use EMPTY_VALUE for doubles and "" for strings if property is not supported or query fails
      double point = EMPTY_VALUE, tick_value = EMPTY_VALUE, tick_value_profit = EMPTY_VALUE, tick_value_loss = EMPTY_VALUE, tick_size = EMPTY_VALUE;
      double volume_min = EMPTY_VALUE, volume_step = EMPTY_VALUE, swap_long = EMPTY_VALUE, swap_short = EMPTY_VALUE;
      string industry_name = "", description = "";

      //long temp_long_val; // Temporary variable for InfoInteger calls
      double temp_double_val; // Temporary variable for InfoDouble calls
      string temp_string_val; // Temporary variable for InfoString calls

      // Get SYMBOL_POINT
      ResetLastError();
      if(m_symbol_info.InfoDouble(SYMBOL_POINT, temp_double_val))
         point = temp_double_val;

      // Get SYMBOL_TRADE_TICK_VALUE
      ResetLastError();
      if(m_symbol_info.InfoDouble(SYMBOL_TRADE_TICK_VALUE, temp_double_val))
         tick_value = temp_double_val;

      // Get SYMBOL_TRADE_TICK_VALUE_PROFIT
      ResetLastError();
      if(m_symbol_info.InfoDouble(SYMBOL_TRADE_TICK_VALUE_PROFIT, temp_double_val))
         tick_value_profit = temp_double_val;

      // Get SYMBOL_TRADE_TICK_VALUE_LOSS
      ResetLastError();
      if(m_symbol_info.InfoDouble(SYMBOL_TRADE_TICK_VALUE_LOSS, temp_double_val))
         tick_value_loss = temp_double_val;

      // Get SYMBOL_TRADE_TICK_SIZE
      ResetLastError();
      if(m_symbol_info.InfoDouble(SYMBOL_TRADE_TICK_SIZE, temp_double_val))
         tick_size = temp_double_val;

      // Get SYMBOL_VOLUME_MIN
      ResetLastError();
      if(m_symbol_info.InfoDouble(SYMBOL_VOLUME_MIN, temp_double_val))
         volume_min = temp_double_val;

      // Get SYMBOL_VOLUME_STEP
      ResetLastError();
      if(m_symbol_info.InfoDouble(SYMBOL_VOLUME_STEP, temp_double_val))
         volume_step = temp_double_val;

      // Get SYMBOL_SWAP_LONG
      ResetLastError();
      if(m_symbol_info.InfoDouble(SYMBOL_SWAP_LONG, temp_double_val))
         swap_long = temp_double_val;

      // Get SYMBOL_SWAP_SHORT
      ResetLastError();
      if(m_symbol_info.InfoDouble(SYMBOL_SWAP_SHORT, temp_double_val))
         swap_short = temp_double_val;

      // Get SYMBOL_INDUSTRY_NAME (for ETF filter)
      ResetLastError();
      if(m_symbol_info.InfoString(SYMBOL_INDUSTRY_NAME, temp_string_val))
         industry_name = temp_string_val;

      // Get SYMBOL_DESCRIPTION (for Extended Hours filter)
      ResetLastError();
      if(m_symbol_info.InfoString(SYMBOL_DESCRIPTION, temp_string_val))
         description = temp_string_val;

      // --- Filtering Logic ---
      bool passed_filter = true;

      // 1. Name Contains filter
      if(StringLen(Filter_Name_Contains) > 0 && StringFind(symbol_name, Filter_Name_Contains, 0) == -1)
        {
         passed_filter = false;
        }

      // 2. Min Volume filter
      if(passed_filter && (volume_min == EMPTY_VALUE || volume_min < Filter_Min_Volume_Min || volume_min > Filter_Max_Volume_Min))
        {
         passed_filter = false;
        }

      // 3. Volume Step filter
      if(passed_filter && (volume_step == EMPTY_VALUE || volume_step < Filter_Min_Volume_Step || volume_step > Filter_Max_Volume_Step))
        {
         passed_filter = false;
        }

      // 4. ETF filter
      if(passed_filter && Filter_Only_ETFs)
        {
         if(industry_name != "Exchange Traded Fund")  // Case-sensitive match
           {
            passed_filter = false;
           }
        }

      // 5. Extended Hours filter
      if(passed_filter && Filter_Only_Extended_Hours)
        {
         if(StringFind(description, Extended_Hours_Keyword, 0) == -1)  // Case-sensitive search
           {
            passed_filter = false;
           }
        }

      // --- Display Result if all filters passed ---
      if(passed_filter)
        {
         found_count++;

         // Format values for display, handling EMPTY_VALUE and empty strings
         string point_str           = (point == EMPTY_VALUE) ? "N/A" : DoubleToString(point, 5);
         string tick_value_str      = (tick_value == EMPTY_VALUE) ? "N/A" : DoubleToString(tick_value, 2);
         string tick_value_profit_str = (tick_value_profit == EMPTY_VALUE) ? "N/A" : DoubleToString(tick_value_profit, 2);
         string tick_value_loss_str = (tick_value_loss == EMPTY_VALUE) ? "N/A" : DoubleToString(tick_value_loss, 2);
         string tick_size_str       = (tick_size == EMPTY_VALUE) ? "N/A" : DoubleToString(tick_size, 5);
         string volume_min_str      = (volume_min == EMPTY_VALUE) ? "N/A" : DoubleToString(volume_min, 2);
         string volume_step_str     = (volume_step == EMPTY_VALUE) ? "N/A" : DoubleToString(volume_step, 2);
         string swap_long_str       = (swap_long == EMPTY_VALUE) ? "N/A" : DoubleToString(swap_long, 2);
         string swap_short_str      = (swap_short == EMPTY_VALUE) ? "N/A" : DoubleToString(swap_short, 2);

         PrintFormat("%-15s | %-8s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s",
                     symbol_name,
                     point_str,
                     tick_value_str,
                     tick_value_profit_str,
                     tick_value_loss_str,
                     tick_size_str,
                     volume_min_str,
                     volume_step_str,
                     swap_long_str,
                     swap_short_str);
        }
     }

   Print("--------------------------------------------------------------------------------------------------------------------");
   PrintFormat("Scanner Completed. Found symbols: %d", found_count);
   Print("---------------------------------");
  }
//+------------------------------------------------------------------+
