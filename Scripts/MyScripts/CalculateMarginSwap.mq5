//+------------------------------------------------------------------+
//|                                           CalculateMarginSwap.mq5|
//|                                  Copyright 2025, xxxxxxxx       |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "6.02"
#property description "Calculates margin for a custom leverage using official MQL5 formulas."

//--- show the inputs window when the script is launched
#property script_show_inputs

//--- Enum for selectable leverage
enum ENUM_LEVERAGE
  {
   L_1_to_1   = 1,
   L_1_to_2   = 2,
   L_1_to_5   = 5,
   L_1_to_10  = 10,
   L_1_to_20  = 20,
   L_1_to_30  = 30
  };

//--- Input for the user to specify the position size and leverage
input double        InpLotSize = 0.1;
input ENUM_LEVERAGE InpLeverage = L_1_to_1;

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

//--- 2. Calculate Required Margin with CUSTOM LEVERAGE (Official Formulas) ---
   double margin_1_to_1 = 0;

   double contract_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double current_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
   ENUM_SYMBOL_CALC_MODE calc_mode = (ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_CALC_MODE);

   switch(calc_mode)
     {
      case SYMBOL_CALC_MODE_FOREX:
        {
         margin_1_to_1 = InpLotSize * contract_size;
         break;
        }

      case SYMBOL_CALC_MODE_CFD:
      case SYMBOL_CALC_MODE_CFDLEVERAGE:
      case SYMBOL_CALC_MODE_EXCH_STOCKS:
      case SYMBOL_CALC_MODE_SERV_COLLATERAL:
        {
         margin_1_to_1 = InpLotSize * contract_size * current_price;
         break;
        }

      case SYMBOL_CALC_MODE_FUTURES:
      case SYMBOL_CALC_MODE_EXCH_FUTURES:
      case SYMBOL_CALC_MODE_EXCH_FUTURES_FORTS:
        {
         margin_1_to_1 = InpLotSize * SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);
         if(InpLeverage != L_1_to_1)
            Print("Warning: Leverage simulation might be inaccurate for Futures as their margin is fixed.");
         break;
        }

      case SYMBOL_CALC_MODE_CFDINDEX:
        {
         double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
         double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
         if(tick_size > 0)
            margin_1_to_1 = InpLotSize * contract_size * tick_value / tick_size;
         break;
        }

      default:
        {
         Print("Unsupported margin calculation mode for this symbol: ", EnumToString(calc_mode));
         return;
        }
     }

   double margin_required = margin_1_to_1 / (double)InpLeverage;

   if(margin_currency != account_currency)
     {
      double conversion_rate = GetConversionRate(margin_currency, account_currency);
      if(conversion_rate > 0)
         margin_required *= conversion_rate;
      else
         Print("Warning: Could not find conversion rate from ", margin_currency, " to ", account_currency, ". Margin value is in ", margin_currency, ".");
     }

//--- 3. Swap Calculation ---
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
      case SYMBOL_SWAP_MODE_INTEREST_CURRENT:   // Corrected from SYMBOL_CALC_MODE...
        {
         double price = SymbolInfoDouble(symbol, SYMBOL_BID);
         swap_long_cost = (InpLotSize * contract_size * price * (swap_long_raw / 100.0)) / 360.0;
         swap_short_cost = (InpLotSize * contract_size * price * (swap_short_raw / 100.0)) / 360.0;
         break;
        }
      default:
        { swap_long_cost = swap_long_raw; swap_short_cost = swap_short_raw; break; }
     }

//--- 4. Display the Results in the Experts Tab ---
   string base_currency = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
   string profit_currency = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   ENUM_DAY_OF_WEEK triple_swap_day = (ENUM_DAY_OF_WEEK)SymbolInfoInteger(symbol, SYMBOL_SWAP_ROLLOVER3DAYS);
   string swap_unit = SwapModeToString(swap_mode, base_currency, profit_currency, margin_currency);

   Print("--- Margin & Swap Calculation ---");
   PrintFormat("Symbol: %s (%s)", symbol, description);
   PrintFormat("Position Size: %.2f lots", InpLotSize);
   PrintFormat("Simulated Leverage: 1:%d", (int)InpLeverage);
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
