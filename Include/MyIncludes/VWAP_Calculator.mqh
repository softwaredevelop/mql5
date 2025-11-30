//+------------------------------------------------------------------+
//|                                               VWAP_Calculator.mqh|
//|      VERSION 1.40: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Enum for VWAP Reset Period ---
enum ENUM_VWAP_PERIOD
  {
   PERIOD_SESSION,        // Reset every day (can be shifted by timezone)
   PERIOD_WEEK,           // Reset every week
   PERIOD_MONTH,          // Reset every month
   PERIOD_CUSTOM_SESSION  // Reset based on custom start/end times
  };

//+==================================================================+
//|             CLASS 1: CVWAPCalculator (Base Class)                |
//+==================================================================+
class CVWAPCalculator
  {
protected:
   ENUM_VWAP_PERIOD    m_period;
   ENUM_APPLIED_VOLUME m_volume_type;
   bool                m_enabled;
   long                m_tz_shift_seconds; // Timezone shift in seconds

   //--- Persistent Buffers
   double              m_typical_price[];

   //--- Persistent State for Incremental Calculation
   double              m_cumulative_tpv;
   double              m_cumulative_vol;
   int                 m_period_index;
   bool                m_in_session;
   datetime            m_last_time; // Time of the last processed bar

   //--- For custom sessions ---
   int                 m_start_hour, m_start_min;
   int                 m_end_hour, m_end_min;

   bool              IsTimeInSession(const MqlDateTime &dt);

   //--- Updated: Accepts start_index
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CVWAPCalculator(void);
   virtual          ~CVWAPCalculator(void) {};

   bool              Init(ENUM_VWAP_PERIOD period, ENUM_APPLIED_VOLUME vol_type, int tz_shift_hours=0, bool enabled=true);
   bool              Init(string start_time, string end_time, ENUM_APPLIED_VOLUME vol_type, bool enabled=true);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &tick_volume[], const long &volume[], double &vwap_odd[], double &vwap_even[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVWAPCalculator::CVWAPCalculator(void)
  {
   m_enabled = false;
   m_tz_shift_seconds = 0;
   m_cumulative_tpv = 0;
   m_cumulative_vol = 0;
   m_period_index = 0;
   m_in_session = false;
   m_last_time = 0;
  }

//+------------------------------------------------------------------+
//| Init (Standard)                                                  |
//+------------------------------------------------------------------+
bool CVWAPCalculator::Init(ENUM_VWAP_PERIOD period, ENUM_APPLIED_VOLUME vol_type, int tz_shift_hours, bool enabled)
  {
   m_enabled     = enabled;
   if(!m_enabled)
      return true;

   m_period      = period;
   m_volume_type = vol_type;
   m_tz_shift_seconds = tz_shift_hours * 3600;

   if(m_volume_type == VOLUME_REAL && SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT) <= 0)
     {
      Print("VWAP Error: Real Volume is not available for '", _Symbol, "'.");
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Init (Custom Session)                                            |
//+------------------------------------------------------------------+
bool CVWAPCalculator::Init(string start_time, string end_time, ENUM_APPLIED_VOLUME vol_type, bool enabled)
  {
   m_enabled = enabled;
   if(!m_enabled)
      return true;

   m_period      = PERIOD_CUSTOM_SESSION;
   m_volume_type = vol_type;
   m_tz_shift_seconds = 0;

   string parts[];
   if(StringSplit(start_time, ':', parts) == 2)
     {
      m_start_hour = (int)StringToInteger(parts[0]);
      m_start_min  = (int)StringToInteger(parts[1]);
     }
   if(StringSplit(end_time, ':', parts) == 2)
     {
      m_end_hour = (int)StringToInteger(parts[0]);
      m_end_min  = (int)StringToInteger(parts[1]);
     }

   if(m_volume_type == VOLUME_REAL && SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT) <= 0)
     {
      Print("VWAP Error: Real Volume is not available for '", _Symbol, "'.");
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Helper                                                           |
//+------------------------------------------------------------------+
bool CVWAPCalculator::IsTimeInSession(const MqlDateTime &dt)
  {
   int current_time_in_minutes = dt.hour * 60 + dt.min;
   int start_time_in_minutes = m_start_hour * 60 + m_start_min;
   int end_time_in_minutes = m_end_hour * 60 + m_end_min;

   if(end_time_in_minutes < start_time_in_minutes)
      return (current_time_in_minutes >= start_time_in_minutes || current_time_in_minutes < end_time_in_minutes);
   else
      return (current_time_in_minutes >= start_time_in_minutes && current_time_in_minutes < end_time_in_minutes);
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CVWAPCalculator::Calculate(int rates_total, int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[],
                                const long &tick_volume[], const long &volume[], double &vwap_odd[], double &vwap_even[])
  {
   if(!m_enabled || rates_total < 1)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
     {
      start_index = 0;
      // Reset State
      m_cumulative_tpv = 0;
      m_cumulative_vol = 0;
      m_period_index = 0;
      m_in_session = false;
      m_last_time = 0;

      ArrayInitialize(vwap_odd, EMPTY_VALUE);
      ArrayInitialize(vwap_even, EMPTY_VALUE);
     }
   else
     {
      start_index = prev_calculated - 1;
     }

//--- 2. Resize Buffers
   if(ArraySize(m_typical_price) != rates_total)
      ArrayResize(m_typical_price, rates_total);
   if(ArraySize(vwap_odd) != rates_total)
      ArrayResize(vwap_odd, rates_total);
   if(ArraySize(vwap_even) != rates_total)
      ArrayResize(vwap_even, rates_total);

//--- 3. Prepare Price
   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

//--- 4. Main Loop
   for(int i = start_index; i < rates_total; i++)
     {
      // Restore state from member variables (which represent state at i-1)
      double current_cum_tpv = m_cumulative_tpv;
      double current_cum_vol = m_cumulative_vol;
      int current_period_idx = m_period_index;
      bool current_in_session = m_in_session;

      bool new_period = false;

      if(i == 0)
        {
         new_period = true;
        }
      else
        {
         // Check for period change
         switch(m_period)
           {
            case PERIOD_SESSION:
              {
               datetime adjusted_time_curr = time[i] + (datetime)m_tz_shift_seconds;
               datetime adjusted_time_prev = time[i-1] + (datetime)m_tz_shift_seconds;
               MqlDateTime dt_curr, dt_prev;
               TimeToStruct(adjusted_time_curr, dt_curr);
               TimeToStruct(adjusted_time_prev, dt_prev);
               if(dt_curr.day_of_year != dt_prev.day_of_year || dt_curr.year != dt_prev.year)
                  new_period = true;
               break;
              }
            case PERIOD_WEEK:
              {
               MqlDateTime dt_curr, dt_prev;
               TimeToStruct(time[i], dt_curr);
               TimeToStruct(time[i-1], dt_prev);
               if(dt_curr.day_of_week < dt_prev.day_of_week)
                  new_period = true;
               break;
              }
            case PERIOD_MONTH:
              {
               MqlDateTime dt_curr, dt_prev;
               TimeToStruct(time[i], dt_curr);
               TimeToStruct(time[i-1], dt_prev);
               if(dt_curr.mon != dt_prev.mon || dt_curr.year != dt_prev.year)
                  new_period = true;
               break;
              }
            case PERIOD_CUSTOM_SESSION:
              {
               MqlDateTime dt_curr;
               TimeToStruct(time[i], dt_curr);
               bool is_in_current_session = IsTimeInSession(dt_curr);
               if(is_in_current_session && !current_in_session)
                  new_period = true;
               current_in_session = is_in_current_session;
               break;
              }
           }
        }

      if(new_period)
        {
         current_cum_tpv = 0;
         current_cum_vol = 0;
         current_period_idx++;
        }

      long current_volume = (m_volume_type == VOLUME_TICK) ? tick_volume[i] : volume[i];
      if(current_volume < 1)
         current_volume = 1;

      current_cum_tpv += m_typical_price[i] * (double)current_volume;
      current_cum_vol += (double)current_volume;

      double vwap_value = (current_cum_vol > 0) ? current_cum_tpv / current_cum_vol : EMPTY_VALUE;

      // Fill buffers
      if(m_period != PERIOD_CUSTOM_SESSION || current_in_session)
        {
         if(current_period_idx % 2 != 0)
           {
            vwap_odd[i] = vwap_value;
            vwap_even[i] = EMPTY_VALUE; // Clear other buffer to create gap
           }
         else
           {
            vwap_even[i] = vwap_value;
            vwap_odd[i] = EMPTY_VALUE;
           }
        }
      else
        {
         vwap_odd[i] = EMPTY_VALUE;
         vwap_even[i] = EMPTY_VALUE;
        }

      //--- CRITICAL: Update persistent state ONLY if this is NOT the last bar (or if we assume it's closed)
      // Actually, in MT5 OnCalculate, we iterate up to rates_total-1.
      // If we are at i, and i < rates_total-1, then bar i is closed (historical). We can save state.
      // If i == rates_total-1, it is the current forming bar. We should NOT save state,
      // because next tick we will process i again starting from the state of i-1.

      if(i < rates_total - 1)
        {
         m_cumulative_tpv = current_cum_tpv;
         m_cumulative_vol = current_cum_vol;
         m_period_index = current_period_idx;
         m_in_session = current_in_session;
         m_last_time = time[i];
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CVWAPCalculator::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Optimized copy loop
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
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CVWAPCalculator_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

//--- Copy to m_typical_price (Optimized loop)
   for(int i = start_index; i < rates_total; i++)
      m_typical_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
   return true;
  }
//+------------------------------------------------------------------+
