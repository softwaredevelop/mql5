//+------------------------------------------------------------------+
//|                                          SymbolScannerPanel.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored into a class-based structure
#property script_show_inputs
#property description "Scans and filters symbols based on various criteria."

#include <Trade\SymbolInfo.mqh>

//--- Input Parameters for Filtering ---
input string    InpSymbolsToScan      = "";
input string    InpSymbolSeparator    = ",";
input string    InpFilterPathContains = "";
input bool      InpFilterMarketWatch  = true;
input double    InpFilterMinVolMin    = 0.0;
input double    InpFilterMaxVolMin    = 1000000.0;
input double    InpFilterMinVolStep   = 0.0;
input double    InpFilterMaxVolStep   = 1000000.0;
input bool      InpFilterOnlyETFs     = false;
input bool      InpFilterExtendedHours= false;
input string    InpKeywordExtHours    = "(Extended Hours)";

//+------------------------------------------------------------------+
//| CSymbolScanner Class                                             |
//| Encapsulates all logic for scanning and filtering symbols.       |
//+------------------------------------------------------------------+
class CSymbolScanner
  {
private:
   //--- A structure to hold all necessary data for a symbol
   struct SymbolData
     {
      string            name;
      string            path;
      string            description;
      string            industry_name;
      int               spread;
      double            point;
      double            tick_value;
      double            tick_value_profit;
      double            tick_value_loss;
      double            tick_size;
      double            volume_min;
      double            volume_step;
      double            swap_long;
      double            swap_short;
     };

   //--- Filter criteria
   string            m_symbols_to_scan;
   string            m_symbol_separator;
   string            m_filter_path_contains;
   bool              m_filter_market_watch;
   double            m_filter_min_vol_min;
   double            m_filter_max_vol_min;
   double            m_filter_min_vol_step;
   double            m_filter_max_vol_step;
   bool              m_filter_only_etfs;
   bool              m_filter_extended_hours;
   string            m_keyword_ext_hours;

   //--- Internal objects
   CSymbolInfo       m_symbol_info;

public:
   //--- Constructor
                     CSymbolScanner(string symbols, string separator, string path, bool market_watch,
                  double min_vol_min, double max_vol_min, double min_vol_step, double max_vol_step,
                  bool only_etfs, bool ext_hours, string keyword);
   //--- Main execution method
   void              Run(void);

private:
   //--- Helper methods
   bool              GetSymbolsToScan(string &symbols_array[]);
   bool              SymbolPassesFilters(const SymbolData &data);
   void              GatherSymbolData(const string symbol_name, SymbolData &data);
   void              PrintSymbolData(const SymbolData &data);
   void              PrintHeader(void);
   void              PrintFilterCriteria(void);
  };

//+------------------------------------------------------------------+
//| Constructor: Initializes the scanner with filter criteria        |
//+------------------------------------------------------------------+
CSymbolScanner::CSymbolScanner(string symbols, string separator, string path, bool market_watch,
                               double min_vol_min, double max_vol_min, double min_vol_step, double max_vol_step,
                               bool only_etfs, bool ext_hours, string keyword)
  {
   m_symbols_to_scan       = symbols;
   m_symbol_separator      = separator;
   m_filter_path_contains  = path;
   m_filter_market_watch   = market_watch;
   m_filter_min_vol_min    = min_vol_min;
   m_filter_max_vol_min    = max_vol_min;
   m_filter_min_vol_step   = min_vol_step;
   m_filter_max_vol_step   = max_vol_step;
   m_filter_only_etfs      = only_etfs;
   m_filter_extended_hours = ext_hours;
   m_keyword_ext_hours     = keyword;
  }

//+------------------------------------------------------------------+
//| Main execution method                                            |
//+------------------------------------------------------------------+
void CSymbolScanner::Run(void)
  {
   Print("--- Symbol Scanner Panel Started ---");
   PrintFilterCriteria();
   Print("---------------------------------");

   string symbols_to_scan[];
   if(!GetSymbolsToScan(symbols_to_scan))
     {
      Print("No symbols to scan. Exiting.");
      return;
     }

   int found_count = 0;
   PrintHeader();

   SymbolData current_symbol_data;

   for(int i = 0; i < ArraySize(symbols_to_scan); i++)
     {
      string symbol_name = symbols_to_scan[i];
      StringTrimLeft(symbol_name);
      StringTrimRight(symbol_name);

      if(StringLen(symbol_name) == 0)
         continue;

      GatherSymbolData(symbol_name, current_symbol_data);

      if(SymbolPassesFilters(current_symbol_data))
        {
         found_count++;
         PrintSymbolData(current_symbol_data);
        }
     }

   Print("--------------------------------------------------------------------------------------------------------------------------------------------------------");
   PrintFormat("Scanner Completed. Found %d matching symbols.", found_count);
   Print("---------------------------------");
  }

//+------------------------------------------------------------------+
//| Gathers all required data for a single symbol                    |
//+------------------------------------------------------------------+
void CSymbolScanner::GatherSymbolData(const string symbol_name, SymbolData &data)
  {
   if(!m_symbol_info.Name(symbol_name))
      return;
   if(!m_symbol_info.RefreshRates())
      return;

   data.name              = m_symbol_info.Name();
   data.path              = m_symbol_info.Path();
   data.description       = m_symbol_info.Description();
   m_symbol_info.InfoString(SYMBOL_INDUSTRY_NAME, data.industry_name);
   data.spread            = m_symbol_info.Spread();
   data.point             = m_symbol_info.Point();
   data.tick_value        = m_symbol_info.TickValue();
   data.tick_value_profit = m_symbol_info.TickValueProfit();
   data.tick_value_loss   = m_symbol_info.TickValueLoss();
   data.tick_size         = m_symbol_info.TickSize();
   data.volume_min        = m_symbol_info.LotsMin();
   data.volume_step       = m_symbol_info.LotsStep();
   data.swap_long         = m_symbol_info.SwapLong();
   data.swap_short        = m_symbol_info.SwapShort();
  }

//+------------------------------------------------------------------+
//| Checks if a symbol's data meets all the filter criteria          |
//+------------------------------------------------------------------+
bool CSymbolScanner::SymbolPassesFilters(const SymbolData &data)
  {
   if(m_filter_market_watch && !SymbolInfoInteger(data.name, SYMBOL_SELECT))
      return false;

   if(StringLen(m_filter_path_contains) > 0 && StringFind(data.path, m_filter_path_contains) == -1)
      return false;

   if(data.volume_min < m_filter_min_vol_min || data.volume_min > m_filter_max_vol_min)
      return false;

   if(data.volume_step < m_filter_min_vol_step || data.volume_step > m_filter_max_vol_step)
      return false;

   if(m_filter_only_etfs && data.industry_name != "Exchange Traded Fund")
      return false;

   if(m_filter_extended_hours && StringFind(data.description, m_keyword_ext_hours) == -1)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Gets the list of symbols to scan from inputs or the whole market |
//+------------------------------------------------------------------+
bool CSymbolScanner::GetSymbolsToScan(string &symbols_array[])
  {
   string symbols_input_copy = m_symbols_to_scan;
   StringTrimLeft(symbols_input_copy);
   StringTrimRight(symbols_input_copy);

   if(StringLen(symbols_input_copy) > 0)
     {
      StringSplit(symbols_input_copy, StringGetCharacter(m_symbol_separator, 0), symbols_array);
      PrintFormat("%d symbols provided by user.", ArraySize(symbols_array));
     }
   else
     {
      int total_server_symbols = SymbolsTotal(false);
      if(total_server_symbols == 0)
         return false;

      ArrayResize(symbols_array, total_server_symbols);
      for(int j = 0; j < total_server_symbols; j++)
        {
         symbols_array[j] = SymbolName(j, false);
        }
      Print("No specific symbols provided. Scanning all available server symbols.");
     }
   return(ArraySize(symbols_array) > 0);
  }

//+------------------------------------------------------------------+
//| Prints a formatted row of data for a single symbol               |
//+------------------------------------------------------------------+
void CSymbolScanner::PrintSymbolData(const SymbolData &data)
  {
   PrintFormat("%-15s | %-8s | %-8s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s | %-20s",
               data.name,
               (string)data.spread,
               DoubleToString(data.point, -1),
               DoubleToString(data.tick_value, 2),
               DoubleToString(data.tick_value_profit, 2),
               DoubleToString(data.tick_value_loss, 2),
               DoubleToString(data.tick_size, -1),
               DoubleToString(data.volume_min, -1),
               DoubleToString(data.volume_step, -1),
               DoubleToString(data.swap_long, 2),
               DoubleToString(data.swap_short, 2),
               data.path);
  }

//+------------------------------------------------------------------+
//| Prints the header for the output table                           |
//+------------------------------------------------------------------+
void CSymbolScanner::PrintHeader()
  {
   PrintFormat("%-15s | %-8s | %-8s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s | %-20s",
               "Symbol", "Spread", "Point", "TickValue", "TV_Profit", "TV_Loss", "TickSize", "Vol_Min", "Vol_Step", "Swap_Long", "Swap_Short", "Path");
   Print("--------------------------------------------------------------------------------------------------------------------------------------------------------");
  }

//+------------------------------------------------------------------+
//| Prints the filter criteria that the scanner is using             |
//+------------------------------------------------------------------+
void CSymbolScanner::PrintFilterCriteria()
  {
   PrintFormat("Filter Criteria:");
   PrintFormat("  Symbols to Scan: '%s'", m_symbols_to_scan);
   PrintFormat("  Path Contains: '%s'", m_filter_path_contains);
   PrintFormat("  Only Market Watch Selected: %s", (string)m_filter_market_watch);
   PrintFormat("  Min Volume (Min): %g - %g", m_filter_min_vol_min, m_filter_max_vol_min);
   PrintFormat("  Volume Step: %g - %g", m_filter_min_vol_step, m_filter_max_vol_step);
   PrintFormat("  Only ETFs: %s", (string)m_filter_only_etfs);
   PrintFormat("  Only Extended Hours: %s (Keyword: '%s')", (string)m_filter_extended_hours, m_keyword_ext_hours);
  }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//--- Create an instance of the scanner with the input parameters
   CSymbolScanner scanner(InpSymbolsToScan, InpSymbolSeparator, InpFilterPathContains, InpFilterMarketWatch,
                          InpFilterMinVolMin, InpFilterMaxVolMin, InpFilterMinVolStep, InpFilterMaxVolStep,
                          InpFilterOnlyETFs, InpFilterExtendedHours, InpKeywordExtHours);
//--- Run the scanner
   scanner.Run();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
