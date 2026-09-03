//+------------------------------------------------------------------+
//|                                  MovingAverage_Anchored_Engine.mqh|
//|      Engine for Universal Session-Anchored Moving Averages       |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.10" // Fixed: ANCHOR_NONE lookback bounds & negative index protection

#ifndef MOVING_AVERAGE_ANCHORED_ENGINE_MQH
#define MOVING_AVERAGE_ANCHORED_ENGINE_MQH

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Anchored Reset Period Enum
#ifndef ENUM_ANCHOR_PERIOD_DEFINED
#define ENUM_ANCHOR_PERIOD_DEFINED
enum ENUM_ANCHOR_PERIOD
  {
   ANCHOR_NONE,           // Standard rolling window (InpPeriod)
   ANCHOR_SESSION,        // Reset every day (Daily anchor)
   ANCHOR_WEEK,           // Reset every week (Weekly anchor)
   ANCHOR_MONTH,          // Reset every month (Monthly anchor)
   ANCHOR_CUSTOM_SESSION  // Reset based on custom broker-time range
  };
#endif

//+==================================================================+
//|             CLASS 1: CMovingAverageAnchoredCalculator            |
//+==================================================================+
class CMovingAverageAnchoredCalculator
  {
protected:
   int                       m_period;
   ENUM_MA_TYPE              m_ma_type;
   ENUM_ANCHOR_PERIOD        m_anchor;
   long                      m_tz_shift_seconds;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;

   //--- Persistent State Buffers
   double                    m_price[];
   double                    m_volume[];
   double                    m_ma_internal[];
   int                       m_anchor_start[];
   int                       m_period_idx[];
   double                    m_temp_ema1[];
   double                    m_temp_ema2[];
   double                    m_temp_ema3[];

   //--- Custom Session Configuration
   int                       m_start_hour, m_start_min;
   int                       m_end_hour, m_end_min;

   bool                      IsTimeInSession(const datetime bar_time);
   virtual bool              PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
         const double &open[], const double &high[], const double &low[], const double &close[]);

   double                    CalculateDynamicEMA(const int idx, const int active_p, const double val, double &ema_array[]);

public:
                     CMovingAverageAnchoredCalculator(void);
   virtual                  ~CMovingAverageAnchoredCalculator(void) {};

   //--- Enhanced Pro Init (6 Parameters)
   bool                      Init(const int period, const ENUM_MA_TYPE ma_type, const ENUM_ANCHOR_PERIOD anchor,
                                  const string custom_start, const string custom_end, const int tz_shift_hours=0,
                                  const ENUM_APPLIED_PRICE_HA_ALL price_source=PRICE_CLOSE_STD);

   //--- Legacy Compatible Init (5 Parameters)
   bool                      Init(int period, ENUM_MA_TYPE ma_type, ENUM_ANCHOR_PERIOD anchor, string custom_start="09:00", string custom_end="18:00")
     {
      return Init(period, ma_type, anchor, custom_start, custom_end, 0, PRICE_CLOSE_STD);
     }

   //--- Standard Calculate with Gapped Segments (Odd & Even, No Volume)
   void                      Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                       const datetime &time[],
                                       const double &open[], const double &high[], const double &low[], const double &close[],
                                       double &ma_odd[], double &ma_even[]);

   //--- Overloaded Calculate with Volume and Gapped Segments (for VWMA support)
   void                      Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                       const datetime &time[],
                                       const double &open[], const double &high[], const double &low[], const double &close[],
                                       const long &volume[],
                                       double &ma_odd[], double &ma_even[]);

   //--- Overloaded Calculate with Double Volume Array (For MTF VWMA)
   void                      Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                       const datetime &time[],
                                       const double &open[], const double &high[], const double &low[], const double &close[],
                                       const double &volume[],
                                       double &ma_odd[], double &ma_even[]);

   //--- Continuous Overloads (Without Gaps)
   void                      Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                       const datetime &time[],
                                       const double &open[], const double &high[], const double &low[], const double &close[],
                                       double &ma_buffer[]);

   void                      Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                       const datetime &time[],
                                       const double &open[], const double &high[], const double &low[], const double &close[],
                                       const long &volume[],
                                       double &ma_buffer[]);

   int                       GetAnchorStart(const int index) const { return (index >= 0 && index < ArraySize(m_anchor_start)) ? m_anchor_start[index] : 0; }
   int                       GetPeriod(void) const { return m_period; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMovingAverageAnchoredCalculator::CMovingAverageAnchoredCalculator(void) :
   m_period(20), m_ma_type(SMA), m_anchor(ANCHOR_SESSION),
   m_tz_shift_seconds(0), m_source_price(PRICE_CLOSE_STD),
   m_start_hour(9), m_start_min(0), m_end_hour(18), m_end_min(0)
  {
   ArraySetAsSeries(m_price,        false);
   ArraySetAsSeries(m_volume,       false);
   ArraySetAsSeries(m_ma_internal,  false);
   ArraySetAsSeries(m_anchor_start, false);
   ArraySetAsSeries(m_period_idx,   false);
   ArraySetAsSeries(m_temp_ema1,    false);
   ArraySetAsSeries(m_temp_ema2,    false);
   ArraySetAsSeries(m_temp_ema3,    false);
  }

//+------------------------------------------------------------------+
//| Enhanced Initialization                                          |
//+------------------------------------------------------------------+
bool CMovingAverageAnchoredCalculator::Init(const int period, const ENUM_MA_TYPE ma_type, const ENUM_ANCHOR_PERIOD anchor,
      const string custom_start, const string custom_end, const int tz_shift_hours,
      const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_period           = (period < 1) ? 1 : period;
   m_ma_type          = ma_type;
   m_anchor           = anchor;
   m_tz_shift_seconds = (long)tz_shift_hours * 3600;
   m_source_price     = price_source;

   if(m_anchor == ANCHOR_CUSTOM_SESSION)
     {
      string start_parts[], end_parts[];
      if(StringSplit(custom_start, ':', start_parts) == 2)
        {
         m_start_hour = (int)StringToInteger(start_parts[0]);
         m_start_min  = (int)StringToInteger(start_parts[1]);
        }
      if(StringSplit(custom_end, ':', end_parts) == 2)
        {
         m_end_hour = (int)StringToInteger(end_parts[0]);
         m_end_min  = (int)StringToInteger(end_parts[1]);
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Stateless Custom Session In-Time Check                           |
//+------------------------------------------------------------------+
bool CMovingAverageAnchoredCalculator::IsTimeInSession(const datetime bar_time)
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
//| Dynamic EMA Smoothing on Adaptive Step                           |
//+------------------------------------------------------------------+
double CMovingAverageAnchoredCalculator::CalculateDynamicEMA(const int idx, const int active_p, const double val, double &ema_array[])
  {
   double pr = 2.0 / (double)(active_p + 1.0);
   if(idx == m_anchor_start[idx] || ema_array[idx - 1] == EMPTY_VALUE)
      ema_array[idx] = val;
   else
      ema_array[idx] = val * pr + ema_array[idx - 1] * (1.0 - pr);
   return ema_array[idx];
  }

//+------------------------------------------------------------------+
//| Calculate (Segmented - No Volume)                                 |
//+------------------------------------------------------------------+
void CMovingAverageAnchoredCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const datetime &time[],
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &ma_odd[], double &ma_even[])
  {
   long dummy_vol[];
   ArrayResize(dummy_vol, rates_total);
   ArrayInitialize(dummy_vol, 1);
   Calculate(rates_total, prev_calculated, price_type, time, open, high, low, close, dummy_vol, ma_odd, ma_even);
  }

//+------------------------------------------------------------------+
//| Calculate (Segmented - Long Volume Overload)                     |
//+------------------------------------------------------------------+
void CMovingAverageAnchoredCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const datetime &time[],
      const double &open[], const double &high[], const double &low[], const double &close[],
      const long &volume[],
      double &ma_odd[], double &ma_even[])
  {
   double vol_double[];
   ArrayResize(vol_double, rates_total);
   ArraySetAsSeries(vol_double, false);

   int start = (prev_calculated > 0) ? (prev_calculated - 1) : 0;
   for(int i = start; i < rates_total; i++)
      vol_double[i] = (volume[i] < 1) ? 1.0 : (double)volume[i];

   Calculate(rates_total, prev_calculated, price_type, time, open, high, low, close, vol_double, ma_odd, ma_even);
  }

//+------------------------------------------------------------------+
//| Calculate (Segmented - Double Volume Overload for MTF)           |
//+------------------------------------------------------------------+
void CMovingAverageAnchoredCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const datetime &time[],
      const double &open[], const double &high[], const double &low[], const double &close[],
      const double &volume[],
      double &ma_odd[], double &ma_even[])
  {
   if(rates_total < 2)
      return;

// Safe allocation of destination arrays
   if(ArraySize(ma_odd) != rates_total)
     {
      ArrayResize(ma_odd, rates_total);
      ArraySetAsSeries(ma_odd, false);
      ArrayInitialize(ma_odd, EMPTY_VALUE);
     }
   if(ArraySize(ma_even) != rates_total)
     {
      ArrayResize(ma_even, rates_total);
      ArraySetAsSeries(ma_even, false);
      ArrayInitialize(ma_even, EMPTY_VALUE);
     }

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

// Resize internal state buffers safely without wiping history
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price,        rates_total);
      ArraySetAsSeries(m_price,        false);
      ArrayResize(m_volume,       rates_total);
      ArraySetAsSeries(m_volume,       false);
      ArrayResize(m_ma_internal,  rates_total);
      ArraySetAsSeries(m_ma_internal,  false);
      ArrayResize(m_anchor_start, rates_total);
      ArraySetAsSeries(m_anchor_start, false);
      ArrayResize(m_period_idx,   rates_total);
      ArraySetAsSeries(m_period_idx,   false);
      ArrayResize(m_temp_ema1,    rates_total);
      ArraySetAsSeries(m_temp_ema1,    false);
      ArrayResize(m_temp_ema2,    rates_total);
      ArraySetAsSeries(m_temp_ema2,    false);
      ArrayResize(m_temp_ema3,    rates_total);
      ArraySetAsSeries(m_temp_ema3,    false);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   for(int i = start_index; i < rates_total; i++)
      m_volume[i] = (volume[i] < 1.0) ? 1.0 : volume[i];

   int    period_index = 0;
   int    anchor_bar   = 0;
   bool   in_session   = false;

   for(int i = 0; i < rates_total; i++)
     {
      bool new_period = false;

      if(m_anchor == ANCHOR_CUSTOM_SESSION)
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
            switch(m_anchor)
              {
               case ANCHOR_SESSION:
                 {
                  datetime curr_t = time[i]     + (datetime)m_tz_shift_seconds;
                  datetime prev_t = time[i - 1] + (datetime)m_tz_shift_seconds;
                  MqlDateTime dt_c, dt_p;
                  TimeToStruct(curr_t, dt_c);
                  TimeToStruct(prev_t, dt_p);
                  if(dt_c.day_of_year != dt_p.day_of_year || dt_c.year != dt_p.year)
                     new_period = true;
                  break;
                 }
               case ANCHOR_WEEK:
                 {
                  MqlDateTime dt_c, dt_p;
                  TimeToStruct(time[i], dt_c);
                  TimeToStruct(time[i - 1], dt_p);
                  if(dt_c.day_of_week < dt_p.day_of_week)
                     new_period = true;
                  break;
                 }
               case ANCHOR_MONTH:
                 {
                  MqlDateTime dt_c, dt_p;
                  TimeToStruct(time[i], dt_c);
                  TimeToStruct(time[i - 1], dt_p);
                  if(dt_c.mon != dt_p.mon || dt_c.year != dt_p.year)
                     new_period = true;
                  break;
                 }
               case ANCHOR_NONE:
               default:
                  break;
              }
           }
        }

      if(new_period)
        {
         period_index++;
         anchor_bar = i;
        }

      m_anchor_start[i] = anchor_bar;
      m_period_idx[i]   = period_index;

      if(in_session)
        {
         // Robust lookback calculation guaranteed not to exceed available bars
         int elapsed_bars = i - anchor_bar + 1;
         int active_p     = MathMin(m_period, elapsed_bars);
         if(active_p < 1)
            active_p = 1;

         if(i == anchor_bar)
           {
            m_ma_internal[i] = m_price[i];
            m_temp_ema1[i]   = m_price[i];
            m_temp_ema2[i]   = m_price[i];
            m_temp_ema3[i]   = m_price[i];
           }
         else
           {
            switch(m_ma_type)
              {
               case EMA:
                  m_ma_internal[i] = CalculateDynamicEMA(i, active_p, m_price[i], m_temp_ema1);
                  break;

               case SMMA:
                 {
                  double pr = 1.0 / (double)active_p;
                  m_ma_internal[i] = m_price[i] * pr + m_ma_internal[i - 1] * (1.0 - pr);
                  break;
                 }

               case LWMA:
                 {
                  double sum = 0.0, w_sum = 0.0;
                  for(int k = 0; k < active_p; k++)
                    {
                     int idx = i - k;
                     if(idx < 0)
                        break; // Defensive Bounds Guard
                     double w = (double)(active_p - k);
                     sum += m_price[idx] * w;
                     w_sum += w;
                    }
                  m_ma_internal[i] = (w_sum > 0.0) ? (sum / w_sum) : m_price[i];
                  break;
                 }

               case TMA:
                 {
                  int period1 = (int)ceil((active_p + 1.0) / 2.0);
                  double sum_tp = 0.0;
                  int count_tp = 0;
                  for(int j = 0; j < period1; j++)
                    {
                     int idx = i - j;
                     if(idx < 0)
                        break;
                     sum_tp += m_price[idx];
                     count_tp++;
                    }
                  m_temp_ema1[i] = (count_tp > 0) ? (sum_tp / (double)count_tp) : m_price[i];

                  int period2 = active_p - period1 + 1;
                  double sum_f = 0.0;
                  int count_f = 0;
                  for(int j = 0; j < period2; j++)
                    {
                     int idx = i - j;
                     if(idx < 0)
                        break;
                     sum_f += m_temp_ema1[idx];
                     count_f++;
                    }
                  m_ma_internal[i] = (count_f > 0) ? (sum_f / (double)count_f) : m_temp_ema1[i];
                  break;
                 }

               case DEMA:
                 {
                  double ema1 = CalculateDynamicEMA(i, active_p, m_price[i], m_temp_ema1);
                  double ema2 = CalculateDynamicEMA(i, active_p, ema1, m_temp_ema2);
                  m_ma_internal[i] = 2.0 * ema1 - ema2;
                  break;
                 }

               case TEMA:
                 {
                  double ema1 = CalculateDynamicEMA(i, active_p, m_price[i], m_temp_ema1);
                  double ema2 = CalculateDynamicEMA(i, active_p, ema1, m_temp_ema2);
                  double ema3 = CalculateDynamicEMA(i, active_p, ema2, m_temp_ema3);
                  m_ma_internal[i] = 3.0 * ema1 - 3.0 * ema2 + ema3;
                  break;
                 }

               case VWMA:
                 {
                  double sum_pv = 0.0, sum_v = 0.0;
                  for(int k = 0; k < active_p; k++)
                    {
                     int idx = i - k;
                     if(idx < 0)
                        break;
                     sum_pv += m_price[idx] * m_volume[idx];
                     sum_v  += m_volume[idx];
                    }
                  m_ma_internal[i] = (sum_v > 0.0) ? (sum_pv / sum_v) : m_price[i];
                  break;
                 }

               default: // SMA
                 {
                  double sum = 0.0;
                  int count = 0;
                  for(int k = 0; k < active_p; k++)
                    {
                     int idx = i - k;
                     if(idx < 0)
                        break; // Defensive Bounds Guard
                     sum += m_price[idx];
                     count++;
                    }
                  m_ma_internal[i] = (count > 0) ? (sum / (double)count) : m_price[i];
                  break;
                 }
              }
           }

         // Segmented Output
         if(period_index % 2 != 0)
           {
            ma_odd[i]  = m_ma_internal[i];
            ma_even[i] = EMPTY_VALUE;
           }
         else
           {
            ma_even[i] = m_ma_internal[i];
            ma_odd[i]  = EMPTY_VALUE;
           }
        }
      else
        {
         ma_odd[i]  = EMPTY_VALUE;
         ma_even[i] = EMPTY_VALUE;
        }
     }
  }

//+------------------------------------------------------------------+
//| Continuous Output Overloads                                      |
//+------------------------------------------------------------------+
void CMovingAverageAnchoredCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const datetime &time[],
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &ma_buffer[])
  {
   double odd[], even[];
   Calculate(rates_total, prev_calculated, price_type, time, open, high, low, close, odd, even);

   if(ArraySize(ma_buffer) != rates_total)
     {
      ArrayResize(ma_buffer, rates_total);
      ArraySetAsSeries(ma_buffer, false);
     }

   for(int i = 0; i < rates_total; i++)
     {
      if(odd[i] != EMPTY_VALUE && odd[i] > 0.0)
         ma_buffer[i] = odd[i];
      else
         if(even[i] != EMPTY_VALUE && even[i] > 0.0)
            ma_buffer[i] = even[i];
         else
            ma_buffer[i] = EMPTY_VALUE;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMovingAverageAnchoredCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const datetime &time[],
      const double &open[], const double &high[], const double &low[], const double &close[],
      const long &volume[],
      double &ma_buffer[])
  {
   double odd[], even[];
   Calculate(rates_total, prev_calculated, price_type, time, open, high, low, close, volume, odd, even);

   if(ArraySize(ma_buffer) != rates_total)
     {
      ArrayResize(ma_buffer, rates_total);
      ArraySetAsSeries(ma_buffer, false);
     }

   for(int i = 0; i < rates_total; i++)
     {
      if(odd[i] != EMPTY_VALUE && odd[i] > 0.0)
         ma_buffer[i] = odd[i];
      else
         if(even[i] != EMPTY_VALUE && even[i] > 0.0)
            ma_buffer[i] = even[i];
         else
            ma_buffer[i] = EMPTY_VALUE;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CMovingAverageAnchoredCalculator::PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = high[i];
            break;
         case PRICE_LOW:
            m_price[i] = low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (high[i] + low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i] + low[i] + 2.0 * close[i]) / 4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CMovingAverageAnchoredCalculator_HA         |
//+==================================================================+
class CMovingAverageAnchoredCalculator_HA : public CMovingAverageAnchoredCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double                 m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool           PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
         const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi)                                      |
//+------------------------------------------------------------------+
bool CMovingAverageAnchoredCalculator_HA::PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open,  rates_total);
      ArraySetAsSeries(m_ha_open,  false);
      ArrayResize(m_ha_high,  rates_total);
      ArraySetAsSeries(m_ha_high,  false);
      ArrayResize(m_ha_low,   rates_total);
      ArraySetAsSeries(m_ha_low,   false);
      ArrayResize(m_ha_close, rates_total);
      ArraySetAsSeries(m_ha_close, false);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = m_ha_close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = m_ha_open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = m_ha_high[i];
            break;
         case PRICE_LOW:
            m_price[i] = m_ha_low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) / 4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }

#endif // MOVING_AVERAGE_ANCHORED_ENGINE_MQH
//+------------------------------------------------------------------+
