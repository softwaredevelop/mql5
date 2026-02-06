//+------------------------------------------------------------------+
//|                                     SessionLevels_Calculator.mqh |
//|      Engine for retrieving key Session Levels (D1/W1 etc).       |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

struct SessionLevels
  {
   double            prev_high;
   double            prev_low;
   double            prev_close;
   double            curr_open;
   bool              valid;
  };

//+==================================================================+
//|             CLASS: CSessionLevelsCalculator                      |
//+==================================================================+
class CSessionLevelsCalculator
  {
protected:
   ENUM_TIMEFRAMES   m_session_tf; // Usually PERIOD_D1

   // Cache to prevent repetitive CopyRates calls on every tick
   datetime          m_last_calc_time;
   SessionLevels     m_cached_levels;

public:
                     CSessionLevelsCalculator(void);
   virtual          ~CSessionLevelsCalculator(void) {};

   bool              Init(ENUM_TIMEFRAMES session_tf = PERIOD_D1);

   // Get levels for a specific time (usually TimeCurrent or bar time)
   bool              GetLevels(datetime time, SessionLevels &out_levels);

   // Helper to calculate distance in ATR units
   double            GetDistanceATR(double price, double level, double atr);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSessionLevelsCalculator::CSessionLevelsCalculator(void) :
   m_session_tf(PERIOD_D1),
   m_last_calc_time(0)
  {
   m_cached_levels.valid = false;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CSessionLevelsCalculator::Init(ENUM_TIMEFRAMES session_tf)
  {
   m_session_tf = session_tf;
   return true;
  }

//+------------------------------------------------------------------+
//| Get Levels                                                       |
//+------------------------------------------------------------------+
bool CSessionLevelsCalculator::GetLevels(datetime time, SessionLevels &out_levels)
  {
// 1. Identify the start time of the Session bar containing 'time'
   datetime sess_start = iTime(_Symbol, m_session_tf, iBarShift(_Symbol, m_session_tf, time));

   if(sess_start == 0)
      return false;

// 2. Check Cache
   if(sess_start == m_last_calc_time && m_cached_levels.valid)
     {
      out_levels = m_cached_levels;
      return true;
     }

// 3. Fetch Data
// We need the Current Open and Previous High/Low/Close
// Index 0 in HTF = Current Session. Index 1 = Previous Session.
   int shift = iBarShift(_Symbol, m_session_tf, time);

   double opens[], highs[], lows[], closes[];

// We need index 'shift' (Current) and 'shift+1' (Previous)
// Copying 2 bars starting from shift
   if(CopyOpen(_Symbol, m_session_tf, shift, 2, opens) < 2 ||
      CopyHigh(_Symbol, m_session_tf, shift, 2, highs) < 2 ||
      CopyLow(_Symbol, m_session_tf, shift, 2, lows) < 2 ||
      CopyClose(_Symbol, m_session_tf, shift, 2, closes) < 2)
     {
      return false;
     }

// Array is Standard Order (0 = Oldest = Prev, 1 = Newest = Curr) due to Copy functions default behavior
// unless ArraySetAsSeries is true (it is not here).
// Index 0 = Previous Day
// Index 1 = Current Day

   m_cached_levels.prev_high  = highs[0];
   m_cached_levels.prev_low   = lows[0];
   m_cached_levels.prev_close = closes[0];
   m_cached_levels.curr_open  = opens[1];

   m_cached_levels.valid = true;
   m_last_calc_time = sess_start;

   out_levels = m_cached_levels;
   return true;
  }

//+------------------------------------------------------------------+
//| Helper: Get Signed Distance in ATR                               |
//+------------------------------------------------------------------+
double CSessionLevelsCalculator::GetDistanceATR(double price, double level, double atr)
  {
   if(atr == 0)
      return 0.0;
   return (price - level) / atr;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
