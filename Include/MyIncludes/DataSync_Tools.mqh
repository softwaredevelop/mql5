//+------------------------------------------------------------------+
//|                                           DataSync_Tools.mqh     |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.20" // Enhanced series synchronization checks with 100% backward compatibility

#ifndef DATA_SYNC_TOOLS_MQH
#define DATA_SYNC_TOOLS_MQH

//+==================================================================+
//| Class CDataSync: Centralized Multi-Timeframe Synchronization Daemon|
//+==================================================================+
class CDataSync
  {
public:
   //--- Legacy Data Readiness Helper
   static bool       EnsureDataReady(string symbol, ENUM_TIMEFRAMES tf, int bars_needed = 2, uint timeout_ms = 3000)
     {
      if(!SymbolSelect(symbol, true))
         return false;

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
         Sleep(50);
        }

      PrintFormat("DataSync Timeout: %s on %s. Bars: %d", symbol, EnumToString(tf), available_bars);
      return false;
     }

   //--- High-Performance Stateless HTF Data Ready Checker
   static bool       EnsureHTFDataReady(const string symbol, const ENUM_TIMEFRAMES timeframe, const int required_bars)
     {
      ResetLastError();

      if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
         SymbolSelect(symbol, true);

      datetime times[];
      int copied = CopyTime(symbol, timeframe, 0, required_bars, times);
      return (copied >= required_bars);
     }

   //--- Automated MTF Timer-driven Synchronization & Redraw Daemon
   static void       OnTimerUpdate(const string symbol, const ENUM_TIMEFRAMES timeframe, const int required_bars, bool &data_synced)
     {
      if(!data_synced)
        {
         if(EnsureHTFDataReady(symbol, timeframe, required_bars))
           {
            data_synced = true;
            ChartRedraw(0); // Trigger immediate, flicker-free OnCalculate execution
           }
        }
     }
  };

#endif // DATA_SYNC_TOOLS_MQH
//+------------------------------------------------------------------+