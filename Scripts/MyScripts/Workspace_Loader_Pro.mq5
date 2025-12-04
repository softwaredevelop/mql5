//+------------------------------------------------------------------+
//|                                         Workspace_Loader_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Configurable via Inputs/.set files
#property description "Opens a configurable set of charts and templates for selected symbols."
#property script_show_inputs

//--- Input Parameters
input string InpSymbols = "EURUSD,USDJPY"; // Comma-separated symbols

input group  "Chart Configuration 1"
input ENUM_TIMEFRAMES InpPeriod_1   = PERIOD_M15;
input string          InpTemplate_1 = "Default.tpl"; // Template Name (empty to skip)

input group  "Chart Configuration 2"
input ENUM_TIMEFRAMES InpPeriod_2   = PERIOD_M15;
input string          InpTemplate_2 = "MyTemplates\\trend.ha.base.tpl";

input group  "Chart Configuration 3"
input ENUM_TIMEFRAMES InpPeriod_3   = PERIOD_CURRENT;
input string          InpTemplate_3 = "";

input group  "Chart Configuration 4"
input ENUM_TIMEFRAMES InpPeriod_4   = PERIOD_CURRENT;
input string          InpTemplate_4 = "";

input group  "Chart Configuration 5"
input ENUM_TIMEFRAMES InpPeriod_5   = PERIOD_CURRENT;
input string          InpTemplate_5 = "";

input group  "Chart Configuration 6"
input ENUM_TIMEFRAMES InpPeriod_6   = PERIOD_CURRENT;
input string          InpTemplate_6 = "";

input group  "Chart Configuration 7"
input ENUM_TIMEFRAMES InpPeriod_7   = PERIOD_CURRENT;
input string          InpTemplate_7 = "";

input group  "Chart Configuration 8"
input ENUM_TIMEFRAMES InpPeriod_8   = PERIOD_CURRENT;
input string          InpTemplate_8 = "";

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   string symbols[];
   int count = StringSplit(InpSymbols, ',', symbols);

   if(count <= 0)
     {
      Print("Error: No symbols specified.");
      return;
     }

// Collect configs into arrays for looping
   ENUM_TIMEFRAMES periods[8];
   string templates[8];

   periods[0] = InpPeriod_1;
   templates[0] = InpTemplate_1;
   periods[1] = InpPeriod_2;
   templates[1] = InpTemplate_2;
   periods[2] = InpPeriod_3;
   templates[2] = InpTemplate_3;
   periods[3] = InpPeriod_4;
   templates[3] = InpTemplate_4;
   periods[4] = InpPeriod_5;
   templates[4] = InpTemplate_5;
   periods[5] = InpPeriod_6;
   templates[5] = InpTemplate_6;
   periods[6] = InpPeriod_7;
   templates[6] = InpTemplate_7;
   periods[7] = InpPeriod_8;
   templates[7] = InpTemplate_8;

   for(int i = 0; i < count; i++)
     {
      string symbol = symbols[i];
      StringTrimLeft(symbol);
      StringTrimRight(symbol);

      if(symbol == "")
         continue;

      // Check if symbol exists
      if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
        {
         if(!SymbolSelect(symbol, true))
           {
            Print("Error: Symbol '", symbol, "' not found.");
            continue;
           }
        }

      // Open charts for this symbol
      for(int j = 0; j < 8; j++)
        {
         // Skip empty slots
         if(templates[j] == "")
            continue;

         long chart_id = ChartOpen(symbol, periods[j]);
         if(chart_id > 0)
           {
            if(!ChartApplyTemplate(chart_id, templates[j]))
              {
               Print("Error applying template '", templates[j], "' to ", symbol);
              }
            else
              {
               Print("Opened ", symbol, " ", EnumToString(periods[j]), " with ", templates[j]);
              }
           }
         else
           {
            Print("Error opening chart for ", symbol);
           }
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
