//+------------------------------------------------------------------+
//|                                       Close_Charts_By_Symbol.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Closes charts matching the specified symbols."
#property script_show_inputs

//--- Input Parameters
input string InpSymbols  = "";    // Symbols to close (comma-separated). Leave empty to ignore.
input bool   InpCloseAll = false; // DANGER: Close ALL charts in terminal?

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   if(InpSymbols == "" && !InpCloseAll)
     {
      Alert("Please specify symbols or check 'Close All'.");
      return;
     }

   if(InpCloseAll)
     {
      int ret = MessageBox("Are you sure you want to close ALL charts?", "Confirm Close All", MB_YESNO | MB_ICONWARNING);
      if(ret == IDNO)
         return;
     }

   string symbols_to_close[];
   int target_count = StringSplit(InpSymbols, ',', symbols_to_close);

// Trim spaces
   for(int i=0; i<target_count; i++)
     {
      StringTrimLeft(symbols_to_close[i]);
      StringTrimRight(symbols_to_close[i]);
     }

   long curr_chart = ChartFirst();
   int closed_count = 0;

// Collect IDs first
   long chart_ids[];
   int total_charts = 0;

   while(curr_chart != -1)
     {
      ArrayResize(chart_ids, total_charts + 1);
      chart_ids[total_charts] = curr_chart;
      total_charts++;
      curr_chart = ChartNext(curr_chart);
     }

// Now iterate and close
   for(int i=0; i<total_charts; i++)
     {
      long id = chart_ids[i];
      string sym = ChartSymbol(id);
      if(sym == "")
         continue;

      bool should_close = false;

      if(InpCloseAll)
        {
         should_close = true;
        }
      else
        {
         for(int k=0; k<target_count; k++)
           {
            if(sym == symbols_to_close[k])
              {
               should_close = true;
               break;
              }
           }
        }

      if(should_close)
        {
         if(ChartClose(id))
            closed_count++;
        }
     }

   PrintFormat("Closed %d charts.", closed_count);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
