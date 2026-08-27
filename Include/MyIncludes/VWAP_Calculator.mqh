//+------------------------------------------------------------------+
//|                                               VWAP_Calculator.mqh|
//|      VERSION 3.01: Public Session Query & Bounds Protection       |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.01" // Made IsTimeInSession public for external indicator integration

#ifndef VWAP_CALCULATOR_MQH
#define VWAP_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Enum for VWAP Reset Period ---
#ifndef ENUM_VWAP_PERIOD_DEFINED
#define ENUM_VWAP_PERIOD_DEFINED
enum ENUM_VWAP_PERIOD
  {
   PERIOD_SESSION,        // Reset every day (can be shifted by timezone)
   PERIOD_WEEK,           // Reset every week
   PERIOD_MONTH,          // Reset every month
   PERIOD_CUSTOM_SESSION  // Reset based on custom start/end times
  };
#endif

//+==================================================================+
//|             CLASS 1: CVWAPCalculator (Base Class)                |
//+==================================================================+
class CVWAPCalculator
  {
protected:
   ENUM_VWAP_PERIOD    m_period;
   ENUM_APPLIED_VOLUME m_volume_type;
   bool                m_enabled;
   long                m_tz_shift_seconds;
   int                 m_max_history_days;

   //--- Persistent Price Buffer
   double              m_typical_price[];

   //--- Custom Session Parameters
   int                 m_start_hour, m_start_min;
   int                 m_end_hour, m_end_min;

   virtual bool        PrepareSourceData(const int rates_total, const int start_index,
                                         const double &open[], const double &high[],
                                         const double &low[], const double &close[]);

public:
                     CVWAPCalculator(void);
   virtual            ~CVWAPCalculator(void) {};

   //--- Public Session Query Helper
   bool                IsTimeInSession(const datetime bar_time);

   //--- Backward-Compatible Initialization Signatures
   bool                Init(ENUM_VWAP_PERIOD period, ENUM_APPLIED_VOLUME vol_type, int tz_shift_hours=0, bool enabled=true, int max_history_days=0);
   bool                Init(string start_time, string end_time, ENUM_APPLIED_VOLUME vol_type, bool enabled=true, int max_history_days=0, int tz_shift_hours=0);

   void                Calculate(const int rates_total,
                                 const int prev_calculated,
                                 const datetime &time[],
                                 const double &open[],
                                 const double &high[],
                                 const double &low[],
                                 const double &close[],
                                 const long &tick_volume[],
                                 const long &volume[],
                                 double &vwap_odd[],
                                 double &vwap_even[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVWAPCalculator::CVWAPCalculator(void) : m_period(PERIOD_SESSION),
   m_volume_type(VOLUME_TICK),
   m_enabled(true),
   m_tz_shift_seconds(0),
   m_max_history_days(0),
   m_start_hour(9), m_start_min(30),
   m_end_hour(16), m_end_min(0)
  {
   ArraySetAsSeries(m_typical_price, false);
  }

//+------------------------------------------------------------------+
//| Init (Standard Periods)                                          |
//+------------------------------------------------------------------+
bool CVWAPCalculator::Init(ENUM_VWAP_PERIOD period, ENUM_APPLIED_VOLUME vol_type, int tz_shift_hours, bool enabled, int max_history_days)
  {
   m_enabled          = enabled;
   if(!m_enabled)
      return true;

   m_period           = period;
   m_volume_type      = vol_type;
   m_tz_shift_seconds = (long)tz_shift_hours * 3600;
   m_max_history_days = max_history_days;

   if(m_volume_type == VOLUME_REAL && SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT) <= 0)
     {
      PrintFormat("VWAP Warning: Real Volume not available for '%s'. Falling back to Tick Volume.", _Symbol);
      m_volume_type = VOLUME_TICK;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Init (Custom Session)                                            |
//+------------------------------------------------------------------+
bool CVWAPCalculator::Init(string start_time, string end_time, ENUM_APPLIED_VOLUME vol_type, bool enabled, int max_history_days, int tz_shift_hours)
  {
   m_enabled          = enabled;
   if(!m_enabled)
      return true;

   m_period           = PERIOD_CUSTOM_SESSION;
   m_volume_type      = vol_type;
   m_tz_shift_seconds = (long)tz_shift_hours * 3600;
   m_max_history_days = max_history_days;

   string start_parts[], end_parts[];
   if(StringSplit(start_time, ':', start_parts) == 2)
     {
      m_start_hour = (int)StringToInteger(start_parts[0]);
      m_start_min  = (int)StringToInteger(start_parts[1]);
     }
   if(StringSplit(end_time, ':', end_parts) == 2)
     {
      m_end_hour = (int)StringToInteger(end_parts[0]);
      m_end_min  = (int)StringToInteger(end_parts[1]);
     }

   if(m_volume_type == VOLUME_REAL && SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT) <= 0)
     {
      PrintFormat("VWAP Warning: Real Volume not available for '%s'. Falling back to Tick Volume.", _Symbol);
      m_volume_type = VOLUME_TICK;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Stateless Custom Session In-Time Check (Public)                  |
//+------------------------------------------------------------------+
bool CVWAPCalculator::IsTimeInSession(const datetime bar_time)
  {
   MqlDateTime dt;
   TimeToStruct(bar_time + (datetime)m_tz_shift_seconds, dt);

   int current_min = dt.hour * 60 + dt.min;
   int start_min   = m_start_hour * 60 + m_start_min;
   int end_min     = m_end_hour * 60 + m_end_min;

   if(end_min > start_min)
     {
      return (current_min >= start_min && current_min < end_min);
     }
   else
      if(end_min < start_min)
        {
         return (current_min >= start_min || current_min < end_min);
        }
      else
        {
         return true;
        }
  }

//+------------------------------------------------------------------+
//| Main Calculation (Deterministic & Zero-Flicker)                  |
//+------------------------------------------------------------------+
void CVWAPCalculator::Calculate(const int rates_total,
                                const int prev_calculated,
                                const datetime &time[],
                                const double &open[],
                                const double &high[],
                                const double &low[],
                                const double &close[],
                                const long &tick_volume[],
                                const long &volume[],
                                double &vwap_odd[],
                                double &vwap_even[])
  {
   if(!m_enabled || rates_total < 1)
      return;

//--- Safe array allocation
   if(ArraySize(vwap_odd) != rates_total)
     {
      ArrayResize(vwap_odd, rates_total);
      ArraySetAsSeries(vwap_odd, false);
      ArrayInitialize(vwap_odd, EMPTY_VALUE);
     }
   if(ArraySize(vwap_even) != rates_total)
     {
      ArrayResize(vwap_even, rates_total);
      ArraySetAsSeries(vwap_even, false);
      ArrayInitialize(vwap_even, EMPTY_VALUE);
     }

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

   datetime cutoff_time = 0;
   if(m_max_history_days > 0)
      cutoff_time = TimeCurrent() - (datetime)(m_max_history_days * 86400);

// Deterministic Scan
   double cum_tpv       = 0.0;
   double cum_vol       = 0.0;
   int    period_index  = 0;
   bool   in_session    = false;

   for(int i = 0; i < rates_total; i++)
     {
      bool new_period = false;

      if(m_period == PERIOD_CUSTOM_SESSION)
        {
         bool is_inside = IsTimeInSession(time[i]);
         if(is_inside && !in_session)
            new_period = true;
         in_session = is_inside;
        }
      else
        {
         in_session = true;
         if(i == 0)
           {
            new_period = true;
           }
         else
           {
            switch(m_period)
              {
               case PERIOD_SESSION:
                 {
                  datetime curr_t = time[i] + (datetime)m_tz_shift_seconds;
                  datetime prev_t = time[i - 1] + (datetime)m_tz_shift_seconds;
                  MqlDateTime dt_c, dt_p;
                  TimeToStruct(curr_t, dt_c);
                  TimeToStruct(prev_t, dt_p);
                  if(dt_c.day_of_year != dt_p.day_of_year || dt_c.year != dt_p.year)
                     new_period = true;
                  break;
                 }
               case PERIOD_WEEK:
                 {
                  MqlDateTime dt_c, dt_p;
                  TimeToStruct(time[i], dt_c);
                  TimeToStruct(time[i - 1], dt_p);
                  if(dt_c.day_of_week < dt_p.day_of_week)
                     new_period = true;
                  break;
                 }
               case PERIOD_MONTH:
                 {
                  MqlDateTime dt_c, dt_p;
                  TimeToStruct(time[i], dt_c);
                  TimeToStruct(time[i - 1], dt_p);
                  if(dt_c.mon != dt_p.mon || dt_c.year != dt_p.year)
                     new_period = true;
                  break;
                 }
              }
           }
        }

      // Reset accumulators on session open
      if(new_period)
        {
         cum_tpv = 0.0;
         cum_vol = 0.0;
         period_index++;
        }

      if(in_session)
        {
         long current_vol = (m_volume_type == VOLUME_REAL) ? volume[i] : tick_volume[i];
         if(current_vol < 1)
            current_vol = 1;

         cum_tpv += m_typical_price[i] * (double)current_vol;
         cum_vol += (double)current_vol;

         double vwap_val = (cum_vol > 0.0) ? (cum_tpv / cum_vol) : EMPTY_VALUE;
         bool   show     = (time[i] >= cutoff_time);

         if(period_index % 2 != 0)
           {
            vwap_odd[i]  = show ? vwap_val : EMPTY_VALUE;
            vwap_even[i] = EMPTY_VALUE;
           }
         else
           {
            vwap_even[i] = show ? vwap_val : EMPTY_VALUE;
            vwap_odd[i]  = EMPTY_VALUE;
           }
        }
      else
        {
         vwap_odd[i]  = EMPTY_VALUE;
         vwap_even[i] = EMPTY_VALUE;
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard Typical Price)                           |
//+------------------------------------------------------------------+
bool CVWAPCalculator::PrepareSourceData(const int rates_total, const int start_index,
                                        const double &open[], const double &high[],
                                        const double &low[], const double &close[])
  {
   if(ArraySize(m_typical_price) != rates_total)
     {
      ArrayResize(m_typical_price, rates_total);
      ArraySetAsSeries(m_typical_price, false);
     }

   for(int i = start_index; i < rates_total; i++)
      m_typical_price[i] = (high[i] + low[i] + close[i]) / 3.0;

   return true;
  }

//+==================================================================+
//|             CLASS 2: CVWAPCalculator_HA (Heikin Ashi)            |
//+==================================================================+
class CVWAPCalculator_HA : public CVWAPCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double                 m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool           PrepareSourceData(const int rates_total, const int start_index,
         const double &open[], const double &high[],
         const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi Typical Price)                        |
//+------------------------------------------------------------------+
bool CVWAPCalculator_HA::PrepareSourceData(const int rates_total, const int start_index,
      const double &open[], const double &high[],
      const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open,  rates_total);
      ArrayResize(m_ha_high,  rates_total);
      ArrayResize(m_ha_low,   rates_total);
      ArrayResize(m_ha_close, rates_total);

      ArraySetAsSeries(m_ha_open,  false);
      ArraySetAsSeries(m_ha_high,  false);
      ArraySetAsSeries(m_ha_low,   false);
      ArraySetAsSeries(m_ha_close, false);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   if(ArraySize(m_typical_price) != rates_total)
     {
      ArrayResize(m_typical_price, rates_total);
      ArraySetAsSeries(m_typical_price, false);
     }

   for(int i = start_index; i < rates_total; i++)
      m_typical_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;

   return true;
  }

#endif // VWAP_CALCULATOR_MQH
//+------------------------------------------------------------------+
