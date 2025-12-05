//+------------------------------------------------------------------+
//|                                      List_Chart_Indicators.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Lists all indicators attached to the current chart."
#property script_show_inputs

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   long chart_id = ChartID();
   int windows = (int)ChartGetInteger(chart_id, CHART_WINDOWS_TOTAL);

   Print("--------------------------------------------------");
   PrintFormat("Indicators on Chart %I64d (%s):", chart_id, Symbol());

   for(int w = 0; w < windows; w++)
     {
      int total = ChartIndicatorsTotal(chart_id, w);

      if(total > 0)
        {
         string window_name = (w == 0) ? "Main Window" : StringFormat("Subwindow %d", w);
         PrintFormat("--- %s (%d indicators) ---", window_name, total);

         for(int i = 0; i < total; i++)
           {
            string name = ChartIndicatorName(chart_id, w, i);
            PrintFormat("  [%d] %s", i, name);
           }
        }
     }
   Print("--------------------------------------------------");
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
