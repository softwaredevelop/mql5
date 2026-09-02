//+------------------------------------------------------------------+
//|                                         Workspace_Loader_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.20" // Smart Base Directory & Auto-Path Normalization
#property description "Automated Workspace & Template Bulk Loader."
#property description "Opens and organizes multi-symbol, multi-timeframe chart layouts with templates."
#property script_show_inputs

//--- Input Parameters ---
input group "--- Asset Selection Settings ---"
input bool            InpUseMarketWatch       = false;                 // Load ALL symbols from Market Watch?
input string          InpSymbols              = "EURUSD,GBPUSD,USDJPY";// Comma-separated symbols (if Market Watch = false)
input int             InpMaxSymbols           = 0;                     // Maximum Symbols to process (0 = Unlimited)

input group "--- Template Directory Settings ---"
input string          InpTemplateBaseDir      = "MyTemplates\\Strategies"; // Base Subfolder in Templates\ (empty for root)

input group "--- Execution & Safety Controls ---"
input bool            InpPreventDuplicates    = true;                  // Prevent opening duplicate charts?
input int             InpDelayMs              = 50;                    // Delay between chart opens (ms, prevents UI freeze)

input group "--- Chart Configuration 1 ---"
input ENUM_TIMEFRAMES InpPeriod_1             = PERIOD_M15;            // Slot 1 Timeframe
input string          InpTemplate_1           = "trend.std.tsi_vbands.tpl"; // Slot 1 Template Name/Path (empty to skip)

input group "--- Chart Configuration 2 ---"
input ENUM_TIMEFRAMES InpPeriod_2             = PERIOD_H1;             // Slot 2 Timeframe
input string          InpTemplate_2           = "";                    // Slot 2 Template Name/Path (empty to skip)

input group "--- Chart Configuration 3 ---"
input ENUM_TIMEFRAMES InpPeriod_3             = PERIOD_CURRENT;        // Slot 3 Timeframe
input string          InpTemplate_3           = "";                    // Slot 3 Template Name/Path (empty to skip)

input group "--- Chart Configuration 4 ---"
input ENUM_TIMEFRAMES InpPeriod_4             = PERIOD_CURRENT;        // Slot 4 Timeframe
input string          InpTemplate_4           = "";                    // Slot 4 Template Name/Path (empty to skip)

input group "--- Chart Configuration 5 ---"
input ENUM_TIMEFRAMES InpPeriod_5             = PERIOD_CURRENT;        // Slot 5 Timeframe
input string          InpTemplate_5           = "";                    // Slot 5 Template Name/Path (empty to skip)

input group "--- Chart Configuration 6 ---"
input ENUM_TIMEFRAMES InpPeriod_6             = PERIOD_CURRENT;        // Slot 6 Timeframe
input string          InpTemplate_6           = "";                    // Slot 6 Template Name/Path (empty to skip)

input group "--- Chart Configuration 7 ---"
input ENUM_TIMEFRAMES InpPeriod_7             = PERIOD_CURRENT;        // Slot 7 Timeframe
input string          InpTemplate_7           = "";                    // Slot 7 Template Name/Path (empty to skip)

input group "--- Chart Configuration 8 ---"
input ENUM_TIMEFRAMES InpPeriod_8             = PERIOD_CURRENT;        // Slot 8 Timeframe
input string          InpTemplate_8           = "";                    // Slot 8 Template Name/Path (empty to skip)

//+------------------------------------------------------------------+
//| Helper: Smart path sanitizer and resolver                        |
//+------------------------------------------------------------------+
string FormatTemplatePath(string tpl, string base_dir)
  {
   StringTrimLeft(tpl);
   StringTrimRight(tpl);
   if(tpl == "" || tpl == NULL)
      return "";

// Normalize slashes (/ -> \)
   StringReplace(tpl, "/", "\\");

// Ensure .tpl extension is present
   int len = StringLen(tpl);
   if(len < 4 || StringSubstr(tpl, len - 4) != ".tpl")
      tpl += ".tpl";

// Sanitize base directory
   StringTrimLeft(base_dir);
   StringTrimRight(base_dir);
   StringReplace(base_dir, "/", "\\");

// Remove trailing backslash from base_dir if present
   int base_len = StringLen(base_dir);
   if(base_len > 0 && StringSubstr(base_dir, base_len - 1, 1) == "\\")
      base_dir = StringSubstr(base_dir, 0, base_len - 1);

// If base_dir is specified and tpl does not already start with base_dir or root
   if(base_dir != "")
     {
      // If template is explicitly at root (e.g. "default.tpl")
      if(StringToLower(tpl) == "default.tpl")
         return "default.tpl";

      // If user already typed full relative path matching base_dir, don't duplicate
      if(StringFind(tpl, base_dir) != 0)
         tpl = base_dir + "\\" + tpl;
     }

// Clean any accidental double backslashes
   while(StringFind(tpl, "\\\\") >= 0)
      StringReplace(tpl, "\\\\", "\\");

   return tpl;
  }

//+------------------------------------------------------------------+
//| Helper: Check if chart is already open                           |
//+------------------------------------------------------------------+
bool IsChartAlreadyOpen(const string symbol, const ENUM_TIMEFRAMES period)
  {
   long chart_id = ChartFirst();
   while(chart_id >= 0)
     {
      string cur_sym = ChartSymbol(chart_id);
      ENUM_TIMEFRAMES cur_tf = ChartPeriod(chart_id);

      if(cur_sym == symbol && cur_tf == period)
         return true;

      chart_id = ChartNext(chart_id);
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Script Program Start Function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   string symbols[];
   int count = 0;

// 1. Resolve Symbols
   if(InpUseMarketWatch)
     {
      int total = SymbolsTotal(true);
      if(total <= 0)
        {
         Print("Workspace Loader Error: Market Watch is empty.");
         return;
        }

      ArrayResize(symbols, total);
      for(int i = 0; i < total; i++)
        {
         symbols[i] = SymbolName(i, true);
        }
      count = total;
     }
   else
     {
      string temp[];
      int split = StringSplit(InpSymbols, ',', temp);
      if(split <= 0)
        {
         Print("Workspace Loader Error: No symbols specified in InpSymbols.");
         return;
        }

      int valid_cnt = 0;
      for(int i = 0; i < split; i++)
        {
         string s = temp[i];
         StringTrimLeft(s);
         StringTrimRight(s);
         if(s != "")
           {
            ArrayResize(symbols, valid_cnt + 1);
            symbols[valid_cnt] = s;
            valid_cnt++;
           }
        }
      count = valid_cnt;
     }

   if(InpMaxSymbols > 0 && count > InpMaxSymbols)
      count = InpMaxSymbols;

   if(count <= 0)
     {
      Print("Workspace Loader Error: No valid symbols to process.");
      return;
     }

// 2. Package and Resolve Configurations
   ENUM_TIMEFRAMES periods[8];
   string          templates[8];

   periods[0] = (InpPeriod_1 == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpPeriod_1;
   templates[0] = FormatTemplatePath(InpTemplate_1, InpTemplateBaseDir);

   periods[1] = (InpPeriod_2 == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpPeriod_2;
   templates[1] = FormatTemplatePath(InpTemplate_2, InpTemplateBaseDir);

   periods[2] = (InpPeriod_3 == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpPeriod_3;
   templates[2] = FormatTemplatePath(InpTemplate_3, InpTemplateBaseDir);

   periods[3] = (InpPeriod_4 == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpPeriod_4;
   templates[3] = FormatTemplatePath(InpTemplate_4, InpTemplateBaseDir);

   periods[4] = (InpPeriod_5 == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpPeriod_5;
   templates[4] = FormatTemplatePath(InpTemplate_5, InpTemplateBaseDir);

   periods[5] = (InpPeriod_6 == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpPeriod_6;
   templates[5] = FormatTemplatePath(InpTemplate_6, InpTemplateBaseDir);

   periods[6] = (InpPeriod_7 == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpPeriod_7;
   templates[6] = FormatTemplatePath(InpTemplate_7, InpTemplateBaseDir);

   periods[7] = (InpPeriod_8 == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpPeriod_8;
   templates[7] = FormatTemplatePath(InpTemplate_8, InpTemplateBaseDir);

// 3. Execution Statistics
   int total_opened  = 0;
   int total_applied = 0;
   int total_skipped = 0;
   long last_chart_id = 0;

   PrintFormat("--- Starting Workspace Loader Pro: Processing %d symbols ---", count);

// 4. Main Chart Processing Loop
   for(int i = 0; i < count; i++)
     {
      string symbol = symbols[i];

      // Ensure symbol is selected in Market Watch
      if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
        {
         if(!SymbolSelect(symbol, true))
           {
            PrintFormat("Error: Symbol '%s' does not exist on broker server.", symbol);
            continue;
           }
        }

      // Process up to 8 chart slots per symbol
      for(int j = 0; j < 8; j++)
        {
         if(templates[j] == "")
            continue; // Skip inactive slot

         // Check duplicate prevention
         if(InpPreventDuplicates && IsChartAlreadyOpen(symbol, periods[j]))
           {
            PrintFormat("Skipping duplicate: %s (%s) is already open.", symbol, EnumToString(periods[j]));
            total_skipped++;
            continue;
           }

         // Open Chart
         long chart_id = ChartOpen(symbol, periods[j]);
         if(chart_id > 0)
           {
            total_opened++;
            last_chart_id = chart_id;

            // Apply Template with full relative path
            if(ChartApplyTemplate(chart_id, templates[j]))
              {
               total_applied++;
               PrintFormat("Success: Opened %s [%s] with template '%s'", symbol, EnumToString(periods[j]), templates[j]);
              }
            else
              {
               PrintFormat("Warning: Opened %s [%s], but failed to apply template '%s' (Check if file exists in MQL5\\Profiles\\Templates\\)", symbol, EnumToString(periods[j]), templates[j]);
              }

            // Micro-delay to avoid UI thread saturation
            if(InpDelayMs > 0)
               Sleep(InpDelayMs);
           }
         else
           {
            PrintFormat("Error: Failed to open chart for %s [%s]", symbol, EnumToString(periods[j]));
           }
        }
     }

// 5. Bring the last opened chart to focus
   if(last_chart_id > 0)
      ChartSetInteger(last_chart_id, CHART_BRING_TO_TOP, true);

   ChartRedraw(0);

// 6. Final Summary Report
   PrintFormat("--- Workspace Loader Pro Completed: %d charts opened, %d templates applied, %d skipped duplicates ---",
               total_opened, total_applied, total_skipped);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
