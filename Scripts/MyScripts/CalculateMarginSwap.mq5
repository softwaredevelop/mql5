//+------------------------------------------------------------------+
//|                                           CalculateMarginSwap.mq5|
//|                                  Copyright 2025, xxxxxxxx       |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.08" // Fixed case scope syntax error.
#property description "Calculates margin and shows swap cost with its calculation method."

//--- show the inputs window when the script is launched
#property script_show_inputs

//--- Input for the user to specify the position size
input double InpLotSize = 0.1;

//--- Forward declarations
string DayOfWeekToString(ENUM_DAY_OF_WEEK day);
string SwapModeToString(ENUM_SYMBOL_SWAP_MODE mode, string base_curr, string profit_curr, string margin_curr);

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//--- Get the current symbol from the chart
   string symbol = _Symbol;

   if(!SymbolSelect(symbol, true))
     {
      Print("Error: Could not select the symbol '", symbol, "'. Please add it to the Market Watch.");
      return;
     }

//--- 1. Gather Symbol Information ---
   string description = SymbolInfoString(symbol, SYMBOL_DESCRIPTION);
   string base_currency = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
   string profit_currency = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   string account_currency = AccountInfoString(ACCOUNT_CURRENCY);
   ENUM_DAY_OF_WEEK triple_swap_day = (ENUM_DAY_OF_WEEK)SymbolInfoInteger(symbol, SYMBOL_SWAP_ROLLOVER3DAYS);
   ENUM_SYMBOL_SWAP_MODE swap_mode = (ENUM_SYMBOL_SWAP_MODE)SymbolInfoInteger(symbol, SYMBOL_SWAP_MODE);

//--- 2. Calculate Required Margin (Always in Account Currency) ---
   double margin_buy = 0, margin_sell = 0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, symbol, InpLotSize, SymbolInfoDouble(symbol, SYMBOL_ASK), margin_buy) ||
      !OrderCalcMargin(ORDER_TYPE_SELL, symbol, InpLotSize, SymbolInfoDouble(symbol, SYMBOL_BID), margin_sell))
     {
      Print("Error calculating margin. Error code: ", GetLastError());
      return;
     }

//--- 3. Calculate Raw Swap Costs ---
   double swap_long_cost = 0, swap_short_cost = 0;
   double swap_long_raw = SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG);
   double swap_short_raw = SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT);

//--- The raw value is calculated without conversion
   switch(swap_mode)
     {
      case SYMBOL_SWAP_MODE_POINTS:
        {
         swap_long_cost = swap_long_raw; // The value is in points
         swap_short_cost = swap_short_raw;
         break;
        }
      case SYMBOL_SWAP_MODE_CURRENCY_SYMBOL:
      case SYMBOL_SWAP_MODE_CURRENCY_MARGIN:
      case SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT:
        {
         swap_long_cost = InpLotSize * swap_long_raw;
         swap_short_cost = InpLotSize * swap_short_raw;
         break;
        }
      case SYMBOL_SWAP_MODE_INTEREST_CURRENT:
        {
         double contract_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
         double price = SymbolInfoDouble(symbol, SYMBOL_BID);
         swap_long_cost = (InpLotSize * contract_size * price * (swap_long_raw / 100.0)) / 360.0;
         swap_short_cost = (InpLotSize * contract_size * price * (swap_short_raw / 100.0)) / 360.0;
         break;
        }
      default:
        {
         swap_long_cost = swap_long_raw;
         swap_short_cost = swap_short_raw;
         break;
        }
     }

//--- 4. Display the Results in the Experts Tab ---
   string swap_unit = SwapModeToString(swap_mode, base_currency, profit_currency, account_currency);

   Print("--- Margin & Swap Calculation ---");
   PrintFormat("Symbol: %s (%s)", symbol, description);
   PrintFormat("Position Size: %.2f lots", InpLotSize);

   Print("\n--- Required Margin ---");
   PrintFormat("BUY Order: %.2f %s", margin_buy, account_currency);
   PrintFormat("SELL Order: %.2f %s", margin_sell, account_currency);

   Print("\n--- Daily Swap Cost ---");
   PrintFormat("Calculation Mode: %s", swap_unit);
   PrintFormat("Long (BUY): %.5f", swap_long_cost);
   PrintFormat("Short (SELL): %.5f", swap_short_cost);
   PrintFormat("Triple Swap Day: %s", DayOfWeekToString(triple_swap_day));
   Print("--- Calculation Complete ---");
  }

//+------------------------------------------------------------------+
//| Converts a swap mode enum to a readable string description.      |
//+------------------------------------------------------------------+
string SwapModeToString(ENUM_SYMBOL_SWAP_MODE mode, string base_curr, string profit_curr, string margin_curr)
  {
   switch(mode)
     {
      case SYMBOL_SWAP_MODE_DISABLED:
         return "Disabled";
      case SYMBOL_SWAP_MODE_POINTS:
         return "In Points";
      case SYMBOL_SWAP_MODE_CURRENCY_SYMBOL:
         return "In " + base_curr + " (Base Currency)";
      case SYMBOL_SWAP_MODE_CURRENCY_MARGIN:
         return "In " + margin_curr + " (Account Currency)";
      case SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT:
         return "In " + profit_curr + " (Quote/Profit Currency)"; // Based on terminal behavior
      case SYMBOL_SWAP_MODE_INTEREST_CURRENT:
         return "Daily cost calculated from annual % in " + profit_curr;
      default:
         return "Unknown Mode (" + (string)mode + ")";
     }
  }

//+------------------------------------------------------------------+
//| Converts a day-of-the-week enum to a readable string             |
//+------------------------------------------------------------------+
string DayOfWeekToString(ENUM_DAY_OF_WEEK day)
  {
   switch(day)
     {
      case SUNDAY:
         return "Sunday";
      case MONDAY:
         return "Monday";
      case TUESDAY:
         return "Tuesday";
      case WEDNESDAY:
         return "Wednesday";
      case THURSDAY:
         return "Thursday";
      case FRIDAY:
         return "Friday";
      case SATURDAY:
         return "Saturday";
      default:
         return "Unknown";
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
