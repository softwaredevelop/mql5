//+------------------------------------------------------------------+
//|                                        InitialBalance_Engine.mqh |
//|                 Quantitative Initial Balance & Forecast Engine   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Fixed: Day-of-Week Struct Encapsulation for Multi-Array Stability
#property library

#ifndef INITIAL_BALANCE_ENGINE_MQH
#define INITIAL_BALANCE_ENGINE_MQH

//--- Enumeration for Forecast calculation mode
enum ENUM_FORECAST_MODE
  {
   FORECAST_PREV_OPEN,      // IB Against Previous Open
   FORECAST_DAY_OF_WEEK     // Filter By Current Day Of Week
  };

//--- Session Phase State
enum ENUM_SESSION_PHASE
  {
   PHASE_OUTSIDE,           // Outside of configured trading session
   PHASE_INITIAL_BALANCE,   // Inside Initial Balance formation window
   PHASE_BREAKOUT_HUNT      // Post-IB session window (Monitoring breakouts)
  };

//--- Data Structure for an Initial Balance Session
struct SIBSession
  {
   datetime          startTime;           // IB Start timestamp
   datetime          ibEndTime;           // IB Formation completion timestamp
   datetime          sessionEndTime;      // End of day/trading session timestamp
   int               dayOfWeek;           // 0 = Sunday, 1 = Monday, ... 6 = Saturday
   double            openPrice;           // Session opening price
   double            top;                 // IB High
   double            bottom;              // IB Low
   double            forecastTop;         // Statistical forecast upper bound
   double            forecastBottom;      // Statistical forecast lower bound
   bool              isIbClosed;          // True when IB period has elapsed
   bool              bullBreakoutArmed;   // Arming flag for single-shot or bar-close
   bool              bearBreakoutArmed;
  };

//--- Struct Wrapper for Day-of-Week Dynamic Arrays (Fixes MQL5 Jagged Array Limitation)
struct SDOWForecastMemory
  {
   double            tops[];
   double            bottoms[];
  };

//+------------------------------------------------------------------+
//| CLASS: CInitialBalanceEngine                                     |
//| High-performance DSP engine for Initial Balance calculations     |
//+------------------------------------------------------------------+
class CInitialBalanceEngine
  {
private:
   //--- Configuration Settings
   bool                 m_auto_session;
   int                  m_ib_duration_sec;
   int                  m_session_start_sec;
   int                  m_session_end_sec;
   int                  m_breakout_end_sec;

   ENUM_FORECAST_MODE   m_forecast_mode;
   int                  m_forecast_length;
   double               m_forecast_mult;

   //--- Persistent Storage for Sessions
   SIBSession           m_sessions[];
   int                  m_total_sessions;

   //--- Rolling Forecast Statistical Memories
   double               m_simple_tops[];
   double               m_simple_bottoms[];
   SDOWForecastMemory   m_dow[7];

   //--- Internal Helpers
   int                  TimeToSeconds(const datetime t) const;
   datetime             GetDayStart(const datetime t) const;
   void                 PushForecastData(const double top_diff, const double bottom_diff, const int dow);
   void                 CalculateForecast(const double open_price, const int dow, double &out_top, double &out_bottom) const;

public:
                     CInitialBalanceEngine(void);
                    ~CInitialBalanceEngine(void) {}

   bool                 Init(const bool auto_session,
                             const string ib_start_str,
                             const string ib_end_str,
                             const string session_end_str,
                             const int ib_duration_minutes,
                             const ENUM_FORECAST_MODE forecast_mode,
                             const int forecast_length,
                             const double forecast_mult);

   void                 Reset(void);

   //--- Core Processing Methods
   int                  ProcessBar(const datetime bar_time,
                                   const double open,
                                   const double high,
                                   const double low,
                                   const double close,
                                   bool &out_bull_breakout,
                                   bool &out_bear_breakout);

   int                  GetSessionsCount(void) const { return m_total_sessions; }
   bool                 GetSession(const int index, SIBSession &out_session) const;
   bool                 GetLastSession(SIBSession &out_session) const;
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CInitialBalanceEngine::CInitialBalanceEngine(void) : m_auto_session(true),
   m_ib_duration_sec(3600),
   m_session_start_sec(30600), // 08:30
   m_session_end_sec(34200),   // 09:30
   m_breakout_end_sec(61200),  // 17:00
   m_forecast_mode(FORECAST_PREV_OPEN),
   m_forecast_length(10),
   m_forecast_mult(1.0),
   m_total_sessions(0)
  {
   ArraySetAsSeries(m_sessions, false);
   ArraySetAsSeries(m_simple_tops, false);
   ArraySetAsSeries(m_simple_bottoms, false);

   for(int i = 0; i < 7; i++)
     {
      ArraySetAsSeries(m_dow[i].tops, false);
      ArraySetAsSeries(m_dow[i].bottoms, false);
     }
  }

//+------------------------------------------------------------------+
//| Convert DateTime to Seconds from Midnight                        |
//+------------------------------------------------------------------+
int CInitialBalanceEngine::TimeToSeconds(const datetime t) const
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 3600 + dt.min * 60 + dt.sec);
  }

//+------------------------------------------------------------------+
//| Get Day Start (Midnight)                                         |
//+------------------------------------------------------------------+
datetime CInitialBalanceEngine::GetDayStart(const datetime t) const
  {
   return (t - (t % 86400));
  }

//+------------------------------------------------------------------+
//| Initialize Engine Configuration                                  |
//+------------------------------------------------------------------+
bool CInitialBalanceEngine::Init(const bool auto_session,
                                 const string ib_start_str,
                                 const string ib_end_str,
                                 const string session_end_str,
                                 const int ib_duration_minutes,
                                 const ENUM_FORECAST_MODE forecast_mode,
                                 const int forecast_length,
                                 const double forecast_mult)
  {
   m_auto_session     = auto_session;
   m_ib_duration_sec  = MathMax(1, ib_duration_minutes) * 60;
   m_forecast_mode    = forecast_mode;
   m_forecast_length  = MathMax(2, forecast_length);
   m_forecast_mult    = MathMax(0.1, forecast_mult);

// Parse time strings (e.g., "08:30")
   string parts[];
   if(StringSplit(ib_start_str, ':', parts) == 2)
      m_session_start_sec = (int)StringToInteger(parts[0]) * 3600 + (int)StringToInteger(parts[1]) * 60;

   if(StringSplit(ib_end_str, ':', parts) == 2)
      m_session_end_sec = (int)StringToInteger(parts[0]) * 3600 + (int)StringToInteger(parts[1]) * 60;

   if(StringSplit(session_end_str, ':', parts) == 2)
      m_breakout_end_sec = (int)StringToInteger(parts[0]) * 3600 + (int)StringToInteger(parts[1]) * 60;

   Reset();
   return true;
  }

//+------------------------------------------------------------------+
//| Reset Dynamic State Arrays                                       |
//+------------------------------------------------------------------+
void CInitialBalanceEngine::Reset(void)
  {
   ArrayFree(m_sessions);
   m_total_sessions = 0;

   ArrayFree(m_simple_tops);
   ArrayFree(m_simple_bottoms);

   for(int i = 0; i < 7; i++)
     {
      ArrayFree(m_dow[i].tops);
      ArrayFree(m_dow[i].bottoms);
     }
  }

//+------------------------------------------------------------------+
//| Push Historical Diffs into Rolling Forecast Arrays               |
//+------------------------------------------------------------------+
void CInitialBalanceEngine::PushForecastData(const double top_diff, const double bottom_diff, const int dow)
  {
   if(m_forecast_mode == FORECAST_DAY_OF_WEEK)
     {
      if(dow < 0 || dow > 6)
         return;
      int sz = ArraySize(m_dow[dow].tops);
      ArrayResize(m_dow[dow].tops, sz + 1);
      ArrayResize(m_dow[dow].bottoms, sz + 1);
      m_dow[dow].tops[sz]    = top_diff;
      m_dow[dow].bottoms[sz] = bottom_diff;

      if(sz + 1 > m_forecast_length)
        {
         for(int k = 0; k < m_forecast_length; k++)
           {
            m_dow[dow].tops[k]    = m_dow[dow].tops[k + 1];
            m_dow[dow].bottoms[k] = m_dow[dow].bottoms[k + 1];
           }
         ArrayResize(m_dow[dow].tops,    m_forecast_length);
         ArrayResize(m_dow[dow].bottoms, m_forecast_length);
        }
     }
   else // FORECAST_PREV_OPEN
     {
      int sz = ArraySize(m_simple_tops);
      ArrayResize(m_simple_tops, sz + 1);
      ArrayResize(m_simple_bottoms, sz + 1);
      m_simple_tops[sz]    = top_diff;
      m_simple_bottoms[sz] = bottom_diff;

      if(sz + 1 > m_forecast_length)
        {
         for(int k = 0; k < m_forecast_length; k++)
           {
            m_simple_tops[k]    = m_simple_tops[k + 1];
            m_simple_bottoms[k] = m_simple_bottoms[k + 1];
           }
         ArrayResize(m_simple_tops,    m_forecast_length);
         ArrayResize(m_simple_bottoms, m_forecast_length);
        }
     }
  }

//+------------------------------------------------------------------+
//| Calculate Statistical Projections for Active Session             |
//+------------------------------------------------------------------+
void CInitialBalanceEngine::CalculateForecast(const double open_price, const int dow, double &out_top, double &out_bottom) const
  {
   out_top    = 0.0;
   out_bottom = 0.0;

   if(m_forecast_mode == FORECAST_DAY_OF_WEEK)
     {
      if(dow < 0 || dow > 6)
         return;
      int sz = ArraySize(m_dow[dow].tops);
      if(sz == 0)
         return;

      double sum_top = 0.0, sum_bot = 0.0;
      for(int i = 0; i < sz; i++)
        {
         sum_top += m_dow[dow].tops[i];
         sum_bot += m_dow[dow].bottoms[i];
        }
      out_top    = open_price + m_forecast_mult * (sum_top / (double)sz);
      out_bottom = open_price + m_forecast_mult * (sum_bot / (double)sz);
     }
   else // FORECAST_PREV_OPEN
     {
      int sz = ArraySize(m_simple_tops);
      if(sz == 0)
         return;

      double sum_top = 0.0, sum_bot = 0.0;
      for(int i = 0; i < sz; i++)
        {
         sum_top += m_simple_tops[i];
         sum_bot += m_simple_bottoms[i];
        }
      out_top    = open_price + m_forecast_mult * (sum_top / (double)sz);
      out_bottom = open_price + m_forecast_mult * (sum_bot / (double)sz);
     }
  }

//+------------------------------------------------------------------+
//| Process a Single Bar through the Initial Balance State Machine   |
//+------------------------------------------------------------------+
int CInitialBalanceEngine::ProcessBar(const datetime bar_time,
                                      const double open,
                                      const double high,
                                      const double low,
                                      const double close,
                                      bool &out_bull_breakout,
                                      bool &out_bear_breakout)
  {
   out_bull_breakout = false;
   out_bear_breakout = false;

   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   int sec_of_day = dt.hour * 3600 + dt.min * 60 + dt.sec;
   int dow        = dt.day_of_week;

   bool is_new_session = false;

   if(m_auto_session)
     {
      // Auto Mode: New session starts on day change
      if(m_total_sessions == 0)
         is_new_session = true;
      else
        {
         MqlDateTime last_dt;
         TimeToStruct(m_sessions[m_total_sessions - 1].startTime, last_dt);
         if(last_dt.day != dt.day || last_dt.mon != dt.mon || last_dt.year != dt.year)
            is_new_session = true;
        }
     }
   else
     {
      // Manual Schedule Mode: Match session start boundary
      if(sec_of_day >= m_session_start_sec)
        {
         if(m_total_sessions == 0)
            is_new_session = true;
         else
           {
            datetime last_start = m_sessions[m_total_sessions - 1].startTime;
            datetime today_start = GetDayStart(bar_time) + m_session_start_sec;
            if(bar_time >= today_start && last_start < today_start)
               is_new_session = true;
           }
        }
     }

// 1. Initialize New Session Structure
   if(is_new_session)
     {
      // Finalize preceding session into historical forecast memory
      if(m_total_sessions >= 1)
        {
         SIBSession prev = m_sessions[m_total_sessions - 1];
         if(m_forecast_mode == FORECAST_DAY_OF_WEEK)
            PushForecastData(prev.top - prev.openPrice, prev.bottom - prev.openPrice, prev.dayOfWeek);
         else
           {
            if(m_total_sessions >= 2)
              {
               SIBSession prev2 = m_sessions[m_total_sessions - 2];
               PushForecastData(prev.top - prev2.openPrice, prev.bottom - prev2.openPrice, prev.dayOfWeek);
              }
           }
        }

      int new_idx = m_total_sessions;
      m_total_sessions++;
      ArrayResize(m_sessions, m_total_sessions, 512);

      m_sessions[new_idx].startTime          = bar_time;
      m_sessions[new_idx].ibEndTime          = bar_time + m_ib_duration_sec;
      m_sessions[new_idx].sessionEndTime     = GetDayStart(bar_time) + (m_auto_session ? 86399 : m_breakout_end_sec);
      m_sessions[new_idx].dayOfWeek          = dow;
      m_sessions[new_idx].openPrice          = open;
      m_sessions[new_idx].top                = high;
      m_sessions[new_idx].bottom             = low;
      m_sessions[new_idx].isIbClosed         = false;
      m_sessions[new_idx].bullBreakoutArmed  = true;
      m_sessions[new_idx].bearBreakoutArmed  = true;

      // Project statistical targets for the session
      CalculateForecast(open, dow, m_sessions[new_idx].forecastTop, m_sessions[new_idx].forecastBottom);
      return new_idx;
     }

   if(m_total_sessions == 0)
      return -1;

   int cur_idx = m_total_sessions - 1;

// 2. State: Inside Initial Balance Formation
   if(!m_sessions[cur_idx].isIbClosed)
     {
      bool inside_ib = false;
      if(m_auto_session)
         inside_ib = (bar_time < m_sessions[cur_idx].ibEndTime);
      else
         inside_ib = (sec_of_day >= m_session_start_sec && sec_of_day < m_session_end_sec);

      if(inside_ib)
        {
         m_sessions[cur_idx].top    = MathMax(m_sessions[cur_idx].top, high);
         m_sessions[cur_idx].bottom = MathMin(m_sessions[cur_idx].bottom, low);
         m_sessions[cur_idx].sessionEndTime = bar_time;
         return cur_idx;
        }
      else
        {
         // Transition to Breakout Phase
         m_sessions[cur_idx].isIbClosed = true;
         m_sessions[cur_idx].ibEndTime  = bar_time;
        }
     }

// 3. State: Breakout Hunting Phase
   bool inside_breakout = false;
   if(m_auto_session)
      inside_breakout = (bar_time >= m_sessions[cur_idx].ibEndTime);
   else
      inside_breakout = (sec_of_day >= m_session_end_sec && sec_of_day <= m_breakout_end_sec);

   if(inside_breakout)
     {
      m_sessions[cur_idx].sessionEndTime = bar_time;

      // Bullish Breakout: Closed above IB High
      if(m_sessions[cur_idx].bullBreakoutArmed && close > m_sessions[cur_idx].top)
        {
         out_bull_breakout = true;
         m_sessions[cur_idx].bullBreakoutArmed = false; // Disarm to prevent repeated spamming
        }

      // Bearish Breakout: Closed below IB Low
      if(m_sessions[cur_idx].bearBreakoutArmed && close < m_sessions[cur_idx].bottom)
        {
         out_bear_breakout = true;
         m_sessions[cur_idx].bearBreakoutArmed = false;
        }
     }

   return cur_idx;
  }

//+------------------------------------------------------------------+
//| Get Session by Index                                             |
//+------------------------------------------------------------------+
bool CInitialBalanceEngine::GetSession(const int index, SIBSession &out_session) const
  {
   if(index < 0 || index >= m_total_sessions)
      return false;
   out_session = m_sessions[index];
   return true;
  }

//+------------------------------------------------------------------+
//| Get Last Active Session                                          |
//+------------------------------------------------------------------+
bool CInitialBalanceEngine::GetLastSession(SIBSession &out_session) const
  {
   if(m_total_sessions <= 0)
      return false;
   out_session = m_sessions[m_total_sessions - 1];
   return true;
  }

#endif // INITIAL_BALANCE_ENGINE_MQH
//+------------------------------------------------------------------+
