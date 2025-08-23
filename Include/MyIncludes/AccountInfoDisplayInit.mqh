//+------------------------------------------------------------------+
//|                                     AccountInfoDisplayInit.mqh   |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""

//--- Enum to define the row index for each piece of information
// This makes the code readable and robust against reordering.
enum ENUM_ACCOUNT_INFO_ROWS
  {
   ROW_HEADING_BASIC,
   ROW_LOGIN,
   ROW_NAME,
   ROW_SERVER,
   ROW_COMPANY,
   ROW_CURRENCY,
   ROW_CURRENCY_DIGITS,
   ROW_HEADING_FINANCIAL,
   ROW_BALANCE,
   ROW_CREDIT,
   ROW_PROFIT,
   ROW_EQUITY,
   ROW_HEADING_MARGIN,
   ROW_MARGIN,
   ROW_MARGIN_FREE,
   ROW_MARGIN_LEVEL,
   ROW_MARGIN_CALL,
   ROW_MARGIN_STOPOUT,
   ROW_HEADING_RULES,
   ROW_TRADE_MODE,
   ROW_LEVERAGE,
   ROW_MARGIN_MODE,
   ROW_STOPOUT_MODE,
   ROW_FIFO_CLOSE,
   ROW_HEDGE_ALLOWED,
   ROW_HEADING_PERMISSIONS,
   ROW_TRADE_ALLOWED,
   ROW_TRADE_EXPERT,
//---
   ROW_TOTAL_COUNT // Always keep this last to get the total count
  };

//--- Array of strings for the labels, matching the enum order
const string g_init_labels[ROW_TOTAL_COUNT] =
  {
   "I. Basic Info",
   "Login:",
   "Name:",
   "Server:",
   "Company:",
   "Currency:",
   "Currency Digits:",
   "II. Financials",
   "Balance:",
   "Credit:",
   "Profit:",
   "Equity:",
   "III. Margin",
   "Margin:",
   "Free Margin:",
   "Margin Level:",
   "Margin Call:",
   "Margin Stopout:",
   "IV. Rules",
   "Trade Mode:",
   "Leverage:",
   "Margin Mode:",
   "Stopout Mode:",
   "FIFO Close:",
   "Hedge Allowed:",
   "V. Permissions",
   "Trade Allowed:",
   "Expert Advisor:",
  };
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
