//+------------------------------------------------------------------+
//|                                             List_Open_Charts.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Lists all open chart symbols to the Experts log."
#property description "Generates a comma-separated list for easy copying."
#property script_show_inputs

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   string symbol_list = "";
   int count = 0;

   long curr_chart = ChartFirst();

// Use a dictionary/array to store unique symbols to avoid duplicates in the list
// Since MQL5 doesn't have a built-in Set, we'll just append and maybe check string find,
// or just list all. Let's list unique symbols for the copy-paste string.

   string unique_symbols[];

   while(curr_chart != -1)
     {
      string symbol = ChartSymbol(curr_chart);
      ENUM_TIMEFRAMES period = ChartPeriod(curr_chart);

      PrintFormat("Chart ID: %I64d | Symbol: %s | Period: %s", curr_chart, symbol, EnumToString(period));

      // Add to unique list
      bool found = false;
      for(int i=0; i<ArraySize(unique_symbols); i++)
        {
         if(unique_symbols[i] == symbol)
           {
            found = true;
            break;
           }
        }

      if(!found)
        {
         int size = ArraySize(unique_symbols);
         ArrayResize(unique_symbols, size + 1);
         unique_symbols[size] = symbol;
        }

      count++;
      curr_chart = ChartNext(curr_chart);
     }

// Build comma-separated string
   for(int i=0; i<ArraySize(unique_symbols); i++)
     {
      if(i > 0)
         symbol_list += ",";
      symbol_list += unique_symbols[i];
     }

   Print("--------------------------------------------------");
   PrintFormat("Total Open Charts: %d", count);
   Print("Unique Symbols List (Copy for Loader/Closer):");
   Print(symbol_list);
   Print("--------------------------------------------------");
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
