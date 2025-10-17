//+------------------------------------------------------------------+
//|                                               VWAP_Calculator.mqh|
//|         Calculation engine for Standard and Heikin Ashi VWAP.    |
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
//|                                                                  |
//|             CLASS 1: CVWAPCalculator (Base Class)                |
//|                                                                  |
//+==================================================================+
class CVWAPCalculator
  {
protected:
   ENUM_VWAP_PERIOD    m_period;
   ENUM_APPLIED_VOLUME m_volume_type;
   double              m_typical_price[];
   bool                m_enabled;
   long                m_tz_shift_seconds; // Timezone shift in seconds

   //--- For custom sessions ---
   int                 m_start_hour, m_start_min;
   int                 m_end_hour, m_end_min;

   bool              IsTimeInSession(const MqlDateTime &dt);
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CVWAPCalculator(void) { m_enabled = false; m_tz_shift_seconds = 0; };
   virtual          ~CVWAPCalculator(void) {};

   bool              Init(ENUM_VWAP_PERIOD period, ENUM_APPLIED_VOLUME vol_type, int tz_shift_hours=0, bool enabled=true);
   bool              Init(string start_time, string end_time, ENUM_APPLIED_VOLUME vol_type, bool enabled=true);
   void              Calculate(int rates_total, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &tick_volume[], const long &volume[], double &vwap_odd[], double &vwap_even[]);
  };

//+------------------------------------------------------------------+
//| CVWAPCalculator: Standard Initialization (Updated)               |
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
//| CVWAPCalculator: Overloaded Init for Custom Sessions             |
//+------------------------------------------------------------------+
bool CVWAPCalculator::Init(string start_time, string end_time, ENUM_APPLIED_VOLUME vol_type, bool enabled)
  {
   m_enabled = enabled;
   if(!m_enabled)
      return true;

   m_period      = PERIOD_CUSTOM_SESSION;
   m_volume_type = vol_type;
   m_tz_shift_seconds = 0; // Custom sessions don't use timezone shift

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
//| Helper function for custom session time check                    |
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
//| CVWAPCalculator: Main Calculation Method (Updated Logic)         |
//+------------------------------------------------------------------+
void CVWAPCalculator::Calculate(int rates_total, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[],
                                const long &tick_volume[], const long &volume[], double &vwap_odd[], double &vwap_even[])
  {
   if(!m_enabled || rates_total < 1)
      return;
   if(!PrepareSourceData(rates_total, open, high, low, close))
      return;

   ArrayInitialize(vwap_odd, EMPTY_VALUE);
   ArrayInitialize(vwap_even, EMPTY_VALUE);

   double cumulative_tpv = 0;
   double cumulative_vol = 0;
   int period_index = 0;
   bool in_session = false;

   for(int i = 0; i < rates_total; i++)
     {
      bool new_period = false;

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
               // CORRECTED: Added (datetime) cast to prevent compiler warnings
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
               if(is_in_current_session && !in_session)
                  new_period = true;
               in_session = is_in_current_session;
               break;
              }
           }
        }

      if(new_period)
        {
         cumulative_tpv = 0;
         cumulative_vol = 0;
         period_index++;
        }

      long current_volume = (m_volume_type == VOLUME_TICK) ? tick_volume[i] : volume[i];
      if(current_volume < 1)
         current_volume = 1;

      cumulative_tpv += m_typical_price[i] * (double)current_volume;
      cumulative_vol += (double)current_volume;

      double vwap_value = (cumulative_vol > 0) ? cumulative_tpv / cumulative_vol : EMPTY_VALUE;

      if(m_period != PERIOD_CUSTOM_SESSION || in_session)
        {
         if(period_index % 2 != 0)
            vwap_odd[i] = vwap_value;
         else
            vwap_even[i] = vwap_value;
        }
     }
  }

//+------------------------------------------------------------------+
//| CVWAPCalculator: Prepares the standard source data.              |
//+------------------------------------------------------------------+
bool CVWAPCalculator::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_typical_price, rates_total);
   for(int i=0; i<rates_total; i++)
      m_typical_price[i] = (high[i] + low[i] + close[i]) / 3.0;
   return true;
  }

//+==================================================================+
//|                                                                  |
//|           CLASS 2: CVWAPCalculator_HA (Heikin Ashi)              |
//|                                                                  |
//+==================================================================+
class CVWAPCalculator_HA : public CVWAPCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CVWAPCalculator_HA: Prepares the HA source data.                 |
//+------------------------------------------------------------------+
bool CVWAPCalculator_HA::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_typical_price, rates_total);
   for(int i=0; i<rates_total; i++)
      m_typical_price[i] = (ha_high[i] + ha_low[i] + ha_close[i]) / 3.0;
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
