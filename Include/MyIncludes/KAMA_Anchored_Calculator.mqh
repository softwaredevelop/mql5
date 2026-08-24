//+------------------------------------------------------------------+
//|                                  KAMA_Anchored_Calculator.mqh   |
//|      Engine for Session-Anchored Kaufman's Adaptive MA (AKAMA)   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // First release of Anchored KAMA Engine

#ifndef KAMA_ANCHORED_CALCULATOR_MQH
#define KAMA_ANCHORED_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Enum for Anchor Reset Period ---
enum ENUM_ANCHOR_PERIOD
  {
   ANCHOR_PERIOD_SESSION,        // Reset every day (with timezone shift)
   ANCHOR_PERIOD_WEEK,           // Reset every week
   ANCHOR_PERIOD_MONTH,          // Reset every month
   ANCHOR_PERIOD_CUSTOM_SESSION  // Reset based on custom start/end times
  };

//+==================================================================+
//|             CLASS: CKamaAnchoredCalculator                       |
//+==================================================================+
class CKamaAnchoredCalculator
  {
private:
   ENUM_ANCHOR_PERIOD      m_anchor_period;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;
   long                    m_tz_shift_seconds;
   int                     m_er_period;
   double                  m_fastest_sc;
   double                  m_slowest_sc;

   //--- Custom Session Times
   int                     m_start_hour, m_start_min;
   int                     m_end_hour, m_end_min;

   //--- Persistent State Buffers
   double                  m_price[];
   double                  m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   //--- Composition Engine
   CHeikinAshi_Calculator  m_ha_engine;

   //--- Internal Methods
   bool                    IsTimeInCustomSession(const MqlDateTime &dt);
   bool                    PreparePriceSeries(const int rates_total,
         const int start_index,
         const double &open[],
         const double &high[],
         const double &low[],
         const double &close[]);

public:
                     CKamaAnchoredCalculator(void);
                    ~CKamaAnchoredCalculator(void) {};

   bool                    Init(const ENUM_ANCHOR_PERIOD anchor_p,
                                const int tz_shift_hours,
                                const string custom_start,
                                const string custom_end,
                                const int er_p,
                                const int fast_p,
                                const int slow_p,
                                const ENUM_APPLIED_PRICE_HA_ALL source);

   void                    Calculate(const int rates_total,
                                     const int prev_calculated,
                                     const datetime &time[],
                                     const double &open[],
                                     const double &high[],
                                     const double &low[],
                                     const double &close[],
                                     double &kama_odd[],
                                     double &kama_even[],
                                     double &out_price[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CKamaAnchoredCalculator::CKamaAnchoredCalculator(void) : m_anchor_period(ANCHOR_PERIOD_SESSION),
   m_source_price(PRICE_CLOSE_STD),
   m_tz_shift_seconds(0),
   m_er_period(10),
   m_fastest_sc(0.6667),
   m_slowest_sc(0.0645),
   m_start_hour(8), m_start_min(0),
   m_end_hour(17), m_end_min(0)
  {
   ArraySetAsSeries(m_price, false);
   ArraySetAsSeries(m_ha_open, false);
   ArraySetAsSeries(m_ha_high, false);
   ArraySetAsSeries(m_ha_low, false);
   ArraySetAsSeries(m_ha_close, false);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CKamaAnchoredCalculator::Init(const ENUM_ANCHOR_PERIOD anchor_p,
                                   const int tz_shift_hours,
                                   const string custom_start,
                                   const string custom_end,
                                   const int er_p,
                                   const int fast_p,
                                   const int slow_p,
                                   const ENUM_APPLIED_PRICE_HA_ALL source)
  {
   m_anchor_period    = anchor_p;
   m_source_price     = source;
   m_tz_shift_seconds = (long)tz_shift_hours * 3600;

   m_er_period = (er_p < 1) ? 1 : er_p;
   int fast_len = (fast_p < 1) ? 1 : fast_p;
   int slow_len = (slow_p < 1) ? 1 : slow_p;

   m_fastest_sc = 2.0 / (fast_len + 1.0);
   m_slowest_sc = 2.0 / (slow_len + 1.0);

   if(m_anchor_period == ANCHOR_PERIOD_CUSTOM_SESSION)
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
//| Custom Session In-Time Check                                     |
//+------------------------------------------------------------------+
bool CKamaAnchoredCalculator::IsTimeInCustomSession(const MqlDateTime &dt)
  {
   int current_min = dt.hour * 60 + dt.min;
   int start_min   = m_start_hour * 60 + m_start_min;
   int end_min     = m_end_hour * 60 + m_end_min;

   if(end_min < start_min)
      return (current_min >= start_min || current_min < end_min);
   else
      return (current_min >= start_min && current_min < end_min);
  }

//+------------------------------------------------------------------+
//| Prepare Price Series (Standard / Heikin Ashi)                    |
//+------------------------------------------------------------------+
bool CKamaAnchoredCalculator::PreparePriceSeries(const int rates_total,
      const int start_index,
      const double &open[],
      const double &high[],
      const double &low[],
      const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false);
     }

   bool is_heikin_ashi = (m_source_price <= PRICE_HA_CLOSE);

   if(is_heikin_ashi)
     {
      if(ArraySize(m_ha_open) != rates_total)
        {
         ArrayResize(m_ha_open, rates_total);
         ArrayResize(m_ha_high, rates_total);
         ArrayResize(m_ha_low, rates_total);
         ArrayResize(m_ha_close, rates_total);

         ArraySetAsSeries(m_ha_open, false);
         ArraySetAsSeries(m_ha_high, false);
         ArraySetAsSeries(m_ha_low, false);
         ArraySetAsSeries(m_ha_close, false);
        }

      m_ha_engine.Calculate(rates_total, start_index, open, high, low, close,
                            m_ha_open, m_ha_high, m_ha_low, m_ha_close);

      for(int i = start_index; i < rates_total; i++)
        {
         switch(m_source_price)
           {
            case PRICE_HA_OPEN:
               m_price[i] = m_ha_open[i];
               break;
            case PRICE_HA_HIGH:
               m_price[i] = m_ha_high[i];
               break;
            case PRICE_HA_LOW:
               m_price[i] = m_ha_low[i];
               break;
            case PRICE_HA_MEDIAN:
               m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
               break;
            case PRICE_HA_TYPICAL:
               m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
               break;
            case PRICE_HA_WEIGHTED:
               m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) / 4.0;
               break;
            case PRICE_HA_CLOSE:
            default:
               m_price[i] = m_ha_close[i];
               break;
           }
        }
     }
   else
     {
      for(int i = start_index; i < rates_total; i++)
        {
         switch(m_source_price)
           {
            case PRICE_OPEN_STD:
               m_price[i] = open[i];
               break;
            case PRICE_HIGH_STD:
               m_price[i] = high[i];
               break;
            case PRICE_LOW_STD:
               m_price[i] = low[i];
               break;
            case PRICE_MEDIAN_STD:
               m_price[i] = (high[i] + low[i]) / 2.0;
               break;
            case PRICE_TYPICAL_STD:
               m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
               break;
            case PRICE_WEIGHTED_STD:
               m_price[i] = (high[i] + low[i] + 2.0 * close[i]) / 4.0;
               break;
            case PRICE_CLOSE_STD:
            default:
               m_price[i] = close[i];
               break;
           }
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Main Incremental Anchored KAMA Calculation                       |
//+------------------------------------------------------------------+
void CKamaAnchoredCalculator::Calculate(const int rates_total,
                                        const int prev_calculated,
                                        const datetime &time[],
                                        const double &open[],
                                        const double &high[],
                                        const double &low[],
                                        const double &close[],
                                        double &kama_odd[],
                                        double &kama_even[],
                                        double &out_price[])
  {
   if(rates_total < 2)
      return;

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(prev_calculated == 0)
     {
      ArrayInitialize(kama_odd,  EMPTY_VALUE);
      ArrayInitialize(kama_even, EMPTY_VALUE);
     }

   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

// Export price series for band variance calculations
   if(ArraySize(out_price) != rates_total)
     {
      ArrayResize(out_price, rates_total);
      ArraySetAsSeries(out_price, false);
     }
   ArrayCopy(out_price, m_price, start_index, start_index, rates_total - start_index);

// Internal variables for continuous session state
   static int  s_period_index = 0;
   static int  s_anchor_bar   = 0;
   static bool s_in_session   = false;
   static double s_last_kama  = 0.0;

   if(prev_calculated == 0)
     {
      s_period_index = 0;
      s_anchor_bar   = 0;
      s_in_session   = false;
      s_last_kama    = 0.0;
     }

   for(int i = start_index; i < rates_total; i++)
     {
      bool new_period = false;

      if(i == 0)
        {
         new_period = true;
        }
      else
        {
         switch(m_anchor_period)
           {
            case ANCHOR_PERIOD_SESSION:
              {
               datetime curr_t = time[i] + (datetime)m_tz_shift_seconds;
               datetime prev_t = time[i - 1] + (datetime)m_tz_shift_seconds;
               MqlDateTime dt_curr, dt_prev;
               TimeToStruct(curr_t, dt_curr);
               TimeToStruct(prev_t, dt_prev);
               if(dt_curr.day_of_year != dt_prev.day_of_year || dt_curr.year != dt_prev.year)
                  new_period = true;
               break;
              }
            case ANCHOR_PERIOD_WEEK:
              {
               MqlDateTime dt_curr, dt_prev;
               TimeToStruct(time[i], dt_curr);
               TimeToStruct(time[i - 1], dt_prev);
               if(dt_curr.day_of_week < dt_prev.day_of_week)
                  new_period = true;
               break;
              }
            case ANCHOR_PERIOD_MONTH:
              {
               MqlDateTime dt_curr, dt_prev;
               TimeToStruct(time[i], dt_curr);
               TimeToStruct(time[i - 1], dt_prev);
               if(dt_curr.mon != dt_prev.mon || dt_curr.year != dt_prev.year)
                  new_period = true;
               break;
              }
            case ANCHOR_PERIOD_CUSTOM_SESSION:
              {
               MqlDateTime dt_curr;
               TimeToStruct(time[i], dt_curr);
               bool inside = IsTimeInCustomSession(dt_curr);
               if(inside && !s_in_session)
                  new_period = true;
               s_in_session = inside;
               break;
              }
           }
        }

      // Period Anchor Reset
      if(new_period)
        {
         s_period_index++;
         s_anchor_bar = i;
         s_last_kama  = m_price[i];
        }

      // Calculate Adaptive Local KAMA within the Anchor Scope
      int bars_in_session = i - s_anchor_bar;
      double current_kama = s_last_kama;

      if(bars_in_session == 0)
        {
         current_kama = m_price[i];
        }
      else
        {
         int lookback = MathMin(bars_in_session, m_er_period);

         double direction = MathAbs(m_price[i] - m_price[i - lookback]);
         double volatility = 0.0;

         for(int j = 0; j < lookback; j++)
            volatility += MathAbs(m_price[i - j] - m_price[i - j - 1]);

         double er = (volatility > 1.0e-9) ? (direction / volatility) : 0.0;
         double sc = MathPow(er * (m_fastest_sc - m_slowest_sc) + m_slowest_sc, 2.0);

         // Recursive smoothing
         current_kama = s_last_kama + sc * (m_price[i] - s_last_kama);
        }

      s_last_kama = current_kama;

      // Odd / Even Segmentation for Gapped Line Rendering
      if(m_anchor_period != ANCHOR_PERIOD_CUSTOM_SESSION || s_in_session)
        {
         if(s_period_index % 2 != 0)
           {
            kama_odd[i]  = current_kama;
            kama_even[i] = EMPTY_VALUE;
           }
         else
           {
            kama_even[i] = current_kama;
            kama_odd[i]  = EMPTY_VALUE;
           }
        }
      else
        {
         kama_odd[i]  = EMPTY_VALUE;
         kama_even[i] = EMPTY_VALUE;
        }
     }
  }

#endif // KAMA_ANCHORED_CALCULATOR_MQH
//+------------------------------------------------------------------+
