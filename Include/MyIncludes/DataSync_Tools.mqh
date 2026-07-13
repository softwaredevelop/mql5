//+------------------------------------------------------------------+
//|                                           DataSync_Tools.mqh     |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Added static EnsureHTFDataReady and automated OnTimerUpdate helper for MTF suites

#ifndef DATA_SYNC_TOOLS_MQH
#define DATA_SYNC_TOOLS_MQH

//+------------------------------------------------------------------+
//| Class CDataSync                                                  |
//+------------------------------------------------------------------+
class CDataSync
  {
public:
   //--- Ensures that data for Symbol/TF is loaded and up-to-date (Legacy Support)
   //--- Returns true if success, false if timeout
   static bool       EnsureDataReady(string symbol, ENUM_TIMEFRAMES tf, int bars_needed = 2, uint timeout_ms = 3000)
     {
      // 1. Check if symbol exists
      if(!SymbolSelect(symbol, true))
         return false;

      // 2. Try to get SeriesInfo to force update
      datetime time_last = (datetime)SeriesInfoInteger(symbol, tf, SERIES_LASTBAR_DATE);

      // 3. Retry loop
      uint start_tick = GetTickCount();
      int available_bars = 0;

      while(GetTickCount() - start_tick < timeout_ms)
        {
         available_bars = Bars(symbol, tf);

         if(available_bars >= bars_needed)
           {
            double check_buff[];
            if(CopyClose(symbol, tf, 0, 1, check_buff) == 1)
               return true;
           }

         // Force update again
         time_last = (datetime)SeriesInfoInteger(symbol, tf, SERIES_LASTBAR_DATE);
         Sleep(50);
        }

      Print(StringFormat("DataSync Timeout: %s on %s. Bars: %d", symbol, EnumToString(tf), available_bars));
      return false;
     }

   //--- NEW: Stateless High-Performance HTF Data Ready Checker (Used by MTF indicators)
   static bool       EnsureHTFDataReady(const string symbol, const ENUM_TIMEFRAMES timeframe, const int required_bars)
     {
      ResetLastError();
      if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
        {
         SymbolSelect(symbol, true);
        }
      datetime times[];
      int copied = CopyTime(symbol, timeframe, 0, required_bars, times);
      return (copied >= required_bars);
     }

   //--- NEW: Automated MTF Timer-driven Synchronisation & Redraw Daemon
   static void       OnTimerUpdate(const string symbol, const ENUM_TIMEFRAMES timeframe, const int required_bars, bool &data_synced)
     {
      if(!data_synced)
        {
         if(EnsureHTFDataReady(symbol, timeframe, required_bars))
           {
            data_synced = true;
            ChartRedraw(); // Force MetaTrader 5 to execute OnCalculate immediately
           }
        }
     }
  };
#endif // DATA_SYNC_TOOLS_MQH
//+------------------------------------------------------------------+
