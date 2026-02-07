//+------------------------------------------------------------------+
//|                                     SessionLevels_Calculator.mqh |
//|      Includes Data Synchronization logic.                        |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\DataSync_Tools.mqh> // Include new tool

struct SessionLevels
  {
   double            prev_high;
   double            prev_low;
   double            prev_close;
   double            curr_open;
   bool              valid;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CSessionLevelsCalculator
  {
protected:
   ENUM_TIMEFRAMES   m_session_tf;
   datetime          m_last_calc_time_bar;
   SessionLevels     m_cached_levels;

public:
                     CSessionLevelsCalculator(void);
   virtual          ~CSessionLevelsCalculator(void) {};

   bool              Init(ENUM_TIMEFRAMES session_tf = PERIOD_D1);
   bool              GetLevels(string symbol, datetime time, SessionLevels &out_levels); // Added 'symbol' param
   double            GetDistanceATR(double price, double level, double atr);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSessionLevelsCalculator::CSessionLevelsCalculator(void) : m_session_tf(PERIOD_D1), m_last_calc_time_bar(0)
  {
   m_cached_levels.valid = false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CSessionLevelsCalculator::Init(ENUM_TIMEFRAMES session_tf)
  {
   m_session_tf = session_tf;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CSessionLevelsCalculator::GetLevels(string symbol, datetime time, SessionLevels &out_levels)
  {
// 0. Ensure Data is Ready (Force Sync)
   if(!CDataSync::EnsureDataReady(symbol, m_session_tf))
      return false;

// 1. Identify start time
   datetime session_start_time = iTime(symbol, m_session_tf, iBarShift(symbol, m_session_tf, time));
   if(session_start_time == 0)
      return false;

// 2. Cache Check (Only works if symbol didn't change! Since we reuse calc, better reset cache or check symbol)
// For safety in script usage (switching symbols), let's skip cache or add symbol check
// Assuming script creates new calc per symbol or we just refresh. Let's force refresh for safety in Script loops.

// 3. Fetch Data
   int shift = iBarShift(symbol, m_session_tf, time);
   if(shift < 0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   if(CopyRates(symbol, m_session_tf, shift, 2, rates) != 2)
      return false;

   m_cached_levels.prev_high  = rates[1].high;
   m_cached_levels.prev_low   = rates[1].low;
   m_cached_levels.prev_close = rates[1].close;
   m_cached_levels.curr_open  = rates[0].open;

   if(m_cached_levels.prev_high == 0 || m_cached_levels.curr_open == 0)
      return false;

   m_cached_levels.valid = true;
   out_levels = m_cached_levels;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CSessionLevelsCalculator::GetDistanceATR(double price, double level, double atr)
  {
   if(atr <= 0.00000001)
      return 0.0;
   return (price - level) / atr;
  }
//+------------------------------------------------------------------+
