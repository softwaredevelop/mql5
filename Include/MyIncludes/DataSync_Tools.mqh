//+------------------------------------------------------------------+
//|                                           DataSync_Tools.mqh     |
//|      Helper for synchronizing Multi-Symbol Multi-TF data.        |
//|      VERSION 1.01: Fixed type conversion warnings (uint).        |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CDataSync
  {
public:
   //--- Ensures that data for Symbol/TF is loaded and up-to-date
   //--- Returns true if success, false if timeout
   static bool       EnsureDataReady(string symbol, ENUM_TIMEFRAMES tf, int bars_needed = 2, uint timeout_ms = 3000)
     {
      // 1. Check if symbol exists
      if(!SymbolSelect(symbol, true))
         return false;

      // 2. Try to get SeriesInfo to force update
      datetime time_last = (datetime)SeriesInfoInteger(symbol, tf, SERIES_LASTBAR_DATE);

      // 3. Retry loop
      uint start_tick = GetTickCount(); // Fixed type: uint
      int available_bars = 0;

      while(GetTickCount() - start_tick < timeout_ms) // Comparison is now uint vs uint
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
  };
//+------------------------------------------------------------------+
