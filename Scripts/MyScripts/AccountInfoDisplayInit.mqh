//+------------------------------------------------------------------+
//|                                       AccountInfoDisplayInit.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

//--- MODIFICATION: Using an enumeration for robust indexing
// This enum provides meaningful names for each row, preventing errors
// if the order of items in init_str changes.
enum ENUM_INFO_ROWS
  {
// --- I. Basic Account Information ---
   ROW_HEADING_BASIC,
   ROW_LOGIN,
   ROW_NAME,
   ROW_SERVER,
   ROW_COMPANY,
   ROW_CURRENCY,
   ROW_CURRENCY_DIGITS,

// --- II. Financial Status and Balances ---
   ROW_HEADING_FINANCIAL,
   ROW_BALANCE,
   ROW_CREDIT,
   ROW_PROFIT,
   ROW_EQUITY,

// --- III. Margin and Risk Management ---
   ROW_HEADING_MARGIN,
   ROW_MARGIN,
   ROW_MARGIN_FREE,
   ROW_MARGIN_LEVEL,
   ROW_MARGIN_CALL,
   ROW_MARGIN_STOPOUT,

// --- IV. Trading Modes and Rules ---
   ROW_HEADING_RULES,
   ROW_TRADE_MODE,
   ROW_LEVERAGE,
   ROW_MARGIN_MODE,
   ROW_STOPOUT_MODE,
   ROW_FIFO_CLOSE,
   ROW_HEDGE_ALLOWED,

// --- V. Trading Permissions ---
   ROW_HEADING_PERMISSIONS,
   ROW_TRADE_ALLOWED,
   ROW_TRADE_EXPERT,

// A special member to get the total count of rows
   ROW_TOTAL_COUNT
  };

//--- The array of strings for display labels.
// The order MUST match the order in ENUM_INFO_ROWS.
string init_str[ROW_TOTAL_COUNT]=
  {
// --- I. Basic Account Information ---
   "I. Basic Account Information",
   "Login",
   "Name",
   "Server",
   "Company",
   "Currency",
   "Currency Digits",

// --- II. Financial Status and Balances ---
   "II. Financial Status and Balances",
   "Balance",
   "Credit",
   "Profit",
   "Equity",

// --- III. Margin and Risk Management ---
   "III. Margin and Risk Management",
   "Margin",
   "Free Margin",
   "Margin Level",
   "Margin Call",
   "Margin StopOut",

// --- IV. Trading Modes and Rules ---
   "IV. Trading Modes and Rules",
   "Trade Mode",
   "Leverage",
   "Margin Mode",
   "Stopout Mode",
   "FIFO Close",
   "Hedge Allowed",

// --- V. Trading Permissions ---
   "V. Trading Permissions",
   "Trade Allowed",
   "Trade Expert"
  };
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
