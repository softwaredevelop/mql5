//+------------------------------------------------------------------+
//|                                           CalculateMarginSwap.mq5|
//|                                  Copyright 2025, xxxxxxxx       |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "7.10"
#property description "Calculates required margin for a custom Margin Rate (%) and swap costs."
#property description "Uses official MQL5 formulas for various instrument types."
#property description "Leverage to Margin Rate Conversion:"
#property description "1:1=100%, 1:2=50%, 1:5=20%, 1:10=10%, 1:20=5%, 1:30=3.33%"

//--- show the inputs window when the script is launched
#property script_show_inputs

//--- Input for the user to specify the position size and margin rate
input double InpLotSize = 0.1;
input double InpMarginRatePercent = 5.0; // Margin Rate in percent (e.g., 5.0 for 5% margin, which is 1:20 leverage)

//--- Forward declarations
string DayOfWeekToString(ENUM_DAY_OF_WEEK day);
string SwapModeToString(ENUM_SYMBOL_SWAP_MODE mode, string base_curr, string profit_curr, string margin_curr);
double GetConversionRate(string from_currency, string to_currency);

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   string symbol = _Symbol;
   string account_currency = AccountInfoString(ACCOUNT_CURRENCY);

   if(!SymbolSelect(symbol, true))
     {
      Print("Error: Could not select the symbol '", symbol, "'. Please add it to the Market Watch.");
      return;
     }

//--- 1. Gather Symbol Information ---
   string description = SymbolInfoString(symbol, SYMBOL_DESCRIPTION);
   string margin_currency = SymbolInfoString(symbol, SYMBOL_CURRENCY_MARGIN);

//--- 2. Calculate the position's full Notional Value ---
   double nominal_value = 0;

   double contract_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double current_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
   ENUM_SYMBOL_CALC_MODE calc_mode = (ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_CALC_MODE);

   switch(calc_mode)
     {
      case SYMBOL_CALC_MODE_FOREX:
        {
         nominal_value = InpLotSize * contract_size;
         break;
        }

      case SYMBOL_CALC_MODE_CFD:
      case SYMBOL_CALC_MODE_CFDLEVERAGE:
      case SYMBOL_CALC_MODE_EXCH_STOCKS:
      case SYMBOL_CALC_MODE_SERV_COLLATERAL:
        {
         nominal_value = InpLotSize * contract_size * current_price;
         break;
        }

      case SYMBOL_CALC_MODE_FUTURES:
      case SYMBOL_CALC_MODE_EXCH_FUTURES:
      case SYMBOL_CALC_MODE_EXCH_FUTURES_FORTS:
        {
         nominal_value = InpLotSize * SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);
         if(InpMarginRatePercent != 100.0)
            Print("Warning: Margin Rate is not applicable for Futures. Showing fixed initial margin.");
         break;
        }

      case SYMBOL_CALC_MODE_CFDINDEX:
        {
         double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
         double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
         if(tick_size > 0)
            nominal_value = InpLotSize * contract_size * tick_value / tick_size;
         break;
        }

      default:
        {
         Print("Unsupported margin calculation mode for this symbol: ", EnumToString(calc_mode));
         return;
        }
     }

   if(margin_currency != account_currency)
     {
      double conversion_rate = GetConversionRate(margin_currency, account_currency);
      if(conversion_rate > 0)
         nominal_value *= conversion_rate;
      else
         Print("Warning: Could not find conversion rate from ", margin_currency, " to ", account_currency, ". Nominal value is in ", margin_currency, ".");
     }

//--- 3. Calculate the final margin based on the notional value and the input margin rate
   double margin_required;
   if(calc_mode == SYMBOL_CALC_MODE_FUTURES || calc_mode == SYMBOL_CALC_MODE_EXCH_FUTURES || calc_mode == SYMBOL_CALC_MODE_EXCH_FUTURES_FORTS)
     {
      margin_required = nominal_value;
     }
   else
     {
      margin_required = nominal_value * (InpMarginRatePercent / 100.0);
     }

//--- 4. Swap Calculation ---
   ENUM_SYMBOL_SWAP_MODE swap_mode = (ENUM_SYMBOL_SWAP_MODE)SymbolInfoInteger(symbol, SYMBOL_SWAP_MODE);
   double swap_long_cost = 0, swap_short_cost = 0;
   double swap_long_raw = SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG);
   double swap_short_raw = SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT);

   switch(swap_mode)
     {
      case SYMBOL_SWAP_MODE_POINTS:
        { swap_long_cost = swap_long_raw; swap_short_cost = swap_short_raw; break; }
      case SYMBOL_SWAP_MODE_CURRENCY_SYMBOL:
      case SYMBOL_SWAP_MODE_CURRENCY_MARGIN:
      case SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT:
        { swap_long_cost = InpLotSize * swap_long_raw; swap_short_cost = InpLotSize * swap_short_raw; break; }
      case SYMBOL_SWAP_MODE_INTEREST_CURRENT:
        {
         double price = SymbolInfoDouble(symbol, SYMBOL_BID);
         swap_long_cost = (InpLotSize * contract_size * price * (swap_long_raw / 100.0)) / 360.0;
         swap_short_cost = (InpLotSize * contract_size * price * (swap_short_raw / 100.0)) / 360.0;
         break;
        }
      default:
        { swap_long_cost = swap_long_raw; swap_short_cost = swap_short_raw; break; }
     }

//--- 5. Display the Results in the Experts Tab ---
   string base_currency = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
   string profit_currency = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   ENUM_DAY_OF_WEEK triple_swap_day = (ENUM_DAY_OF_WEEK)SymbolInfoInteger(symbol, SYMBOL_SWAP_ROLLOVER3DAYS);
   string swap_unit = SwapModeToString(swap_mode, base_currency, profit_currency, margin_currency);

   Print("--- Margin & Swap Calculation ---");
   PrintFormat("Symbol: %s (%s)", symbol, description);
   PrintFormat("Position Size: %.2f lots", InpLotSize);
   PrintFormat("Simulated Margin Rate: %.2f%% (Equivalent to ~1:%.0f leverage)", InpMarginRatePercent, 100.0/InpMarginRatePercent);
   PrintFormat("Calculation Mode: %s", EnumToString(calc_mode));

   Print("\n--- Required Margin ---");
   PrintFormat("Margin for position: %.2f %s", margin_required, account_currency);

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
         return "In " + margin_curr + " (Margin Currency)";
      case SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT:
         return "In " + AccountInfoString(ACCOUNT_CURRENCY) + " (Account Currency)";
      case SYMBOL_SWAP_MODE_INTEREST_CURRENT:
         return "Daily cost from annual % in " + profit_curr;
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
//| Gets the conversion rate between two currencies.                 |
//+------------------------------------------------------------------+
double GetConversionRate(string from_currency, string to_currency)
  {
   if(from_currency == to_currency)
      return 1.0;

   double rate = 0.0;
   string pair_direct = from_currency + to_currency;
   string pair_inverse = to_currency + from_currency;

   SymbolSelect(pair_direct, true);
   SymbolSelect(pair_inverse, true);
   Sleep(50);

   if(SymbolInfoDouble(pair_direct, SYMBOL_ASK, rate) && rate > 0)
      return rate;

   if(SymbolInfoDouble(pair_inverse, SYMBOL_BID, rate) && rate > 0)
      return 1.0 / rate;

   string majors[] = {"USD", "EUR", "GBP", "JPY"};
   for(int i=0; i<ArraySize(majors); i++)
     {
      string major = majors[i];
      if(from_currency != major && to_currency != major)
        {
         double rate1 = GetConversionRate(from_currency, major);
         double rate2 = GetConversionRate(major, to_currency);
         if(rate1 > 0 && rate2 > 0)
            return rate1 * rate2;
        }
     }

   return 0.0;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
