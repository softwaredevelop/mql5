//+------------------------------------------------------------------+
//|                                     KAMA_Anchored_Calculator.mqh |
//|      Kaufman's Adaptive Moving Average with Anchored Resets.      |
//|      VERSION 1.11: Fixed buffer sizing and kama_buffer typos      |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.11" // Fixed persistent buffer sizing and corrected kama_buffer parameter mismatch typos

#ifndef KAMA_ANCHORED_CALCULATOR_MQH
#define KAMA_ANCHORED_CALCULATOR_MQH

#include <MyIncludes\KAMA_Calculator.mqh>

//--- Anchored Reset Period Enum
enum ENUM_ANCHOR_PERIOD
  {
   ANCHOR_NONE,           // Standard rolling window (InpErPeriod)
   ANCHOR_SESSION,        // Reset every day (Daily VWAP style)
   ANCHOR_WEEK,           // Reset every week (Weekly VWAP style)
   ANCHOR_MONTH,          // Reset every month (Monthly VWAP style)
   ANCHOR_CUSTOM_SESSION  // Reset based on custom broker-time range
  };

//+==================================================================+
//|           CLASS: CKamaAnchoredCalculator                         |
//+==================================================================+
class CKamaAnchoredCalculator : public CKamaCalculator
  {
protected:
   ENUM_ANCHOR_PERIOD m_anchor;
   int               m_anchor_start[]; // Tracks the start index of the anchor period for each bar
   int               m_period_idx[];    // Tracks the period count (odd/even) per bar
   double            m_kama_internal[]; // Seamless internal KAMA buffer to preserve recursive state

   // Custom session times
   int               m_start_hour, m_start_min;
   int               m_end_hour, m_end_min;

   bool              IsTimeInSession(datetime time_val);

public:
                     CKamaAnchoredCalculator();
                    ~CKamaAnchoredCalculator() {};

   bool              Init(int er_p, int fast_ema_p, int slow_ema_p, ENUM_ANCHOR_PERIOD anchor, string custom_start="09:00", string custom_end="18:00");

   //--- Upgraded Calculate to output into two separate gapped buffers (Odd & Even)
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const datetime &time[],
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &kama_odd[], double &kama_even[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CKamaAnchoredCalculator::CKamaAnchoredCalculator() : m_anchor(ANCHOR_SESSION)
  {
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CKamaAnchoredCalculator::Init(int er_p, int fast_ema_p, int slow_ema_p, ENUM_ANCHOR_PERIOD anchor, string custom_start, string custom_end)
  {
   if(!CKamaCalculator::Init(er_p, fast_ema_p, slow_ema_p))
      return false;
   m_anchor = anchor;

   string parts[];
   if(StringSplit(custom_start, ':', parts) == 2)
     {
      m_start_hour = (int)StringToInteger(parts[0]);
      m_start_min  = (int)StringToInteger(parts[1]);
     }
   if(StringSplit(custom_end, ':', parts) == 2)
     {
      m_end_hour = (int)StringToInteger(parts[0]);
      m_end_min  = (int)StringToInteger(parts[1]);
     }
   return true;
  }

//+------------------------------------------------------------------+
//| IsTimeInSession                                                  |
//+------------------------------------------------------------------+
bool CKamaAnchoredCalculator::IsTimeInSession(datetime time_val)
  {
   MqlDateTime dt;
   TimeToStruct(time_val, dt);
   int current_min = dt.hour * 60 + dt.min;
   int start_total = m_start_hour * 60 + m_start_min;
   int end_total   = m_end_hour * 60 + m_end_min;

   if(end_total < start_total) // Overlapping midnight session
     {
      return (current_min >= start_total || current_min < end_total);
     }
   else
     {
      return (current_min >= start_total && current_min < end_total);
     }
  }

//+------------------------------------------------------------------+
//| Calculate (Strictly O(1) Non-Repainting Anchored Loop)           |
//+------------------------------------------------------------------+
void CKamaAnchoredCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                        const datetime &time[],
                                        const double &open[], const double &high[], const double &low[], const double &close[],
                                        double &kama_odd[], double &kama_even[])
  {
   if(rates_total <= m_er_period)
      return;

//--- 1. Determine Start Index
   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

//--- 2. Resize Buffers (FIXED: Added sizing for period_idx and kama_internal)
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_anchor_start, rates_total);
      ArrayResize(m_period_idx, rates_total);
      ArrayResize(m_kama_internal, rates_total);
     }

//--- 3. Prepare Price Series
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Calculate KAMA with Anchored Resets
   if(start_index == 0)
     {
      m_anchor_start[0] = 0;
      m_period_idx[0] = 1;
      m_kama_internal[0] = m_price[0]; // FIXED: Corrected array name
      kama_odd[0] = m_price[0];
      kama_even[0] = EMPTY_VALUE;
      start_index = 1;
     }

   for(int i = start_index; i < rates_total; i++)
     {
      bool new_period = false;

      switch(m_anchor)
        {
         case ANCHOR_SESSION:
           {
            MqlDateTime dt_curr, dt_prev;
            TimeToStruct(time[i], dt_curr);
            TimeToStruct(time[i-1], dt_prev);
            if(dt_curr.day_of_year != dt_prev.day_of_year || dt_curr.year != dt_prev.year)
               new_period = true;
            break;
           }
         case ANCHOR_WEEK:
           {
            MqlDateTime dt_curr, dt_prev;
            TimeToStruct(time[i], dt_curr);
            TimeToStruct(time[i-1], dt_prev);
            if(dt_curr.day_of_week < dt_prev.day_of_week)
               new_period = true;
            break;
           }
         case ANCHOR_MONTH:
           {
            MqlDateTime dt_curr, dt_prev;
            TimeToStruct(time[i], dt_curr);
            TimeToStruct(time[i-1], dt_prev);
            if(dt_curr.mon != dt_prev.mon || dt_curr.year != dt_prev.year)
               new_period = true;
            break;
           }
         case ANCHOR_CUSTOM_SESSION:
           {
            MqlDateTime dt_curr, dt_prev;
            TimeToStruct(time[i], dt_curr);
            TimeToStruct(time[i-1], dt_prev);
            int min_curr = dt_curr.hour * 60 + dt_curr.min;
            int min_prev = dt_prev.hour * 60 + dt_prev.min;
            int start_min = m_start_hour * 60 + m_start_min;
            bool day_changed = (dt_curr.day_of_year != dt_prev.day_of_year || dt_curr.year != dt_prev.year);
            if(day_changed)
              {
               if(min_curr >= start_min)
                  new_period = true;
              }
            else
              {
               if(min_prev < start_min && min_curr >= start_min)
                  new_period = true;
              }
            break;
           }
         default:
            break;
        }

      if(new_period)
        {
         m_anchor_start[i] = i;
         m_period_idx[i] = m_period_idx[i-1] + 1;
        }
      else
        {
         m_anchor_start[i] = m_anchor_start[i-1];
         m_period_idx[i] = m_period_idx[i-1];
        }

      int current_anchor_idx = m_anchor_start[i];
      int current_period_idx = m_period_idx[i];

      // Re-initialize KAMA on the reset bar to prevent historical drift
      if(i == current_anchor_idx)
        {
         m_kama_internal[i] = m_price[i]; // FIXED: Corrected array name
        }
      else
        {
         // Calculate the adaptive lookback based on elapsed bars since reset
         int elapsed_bars = i - current_anchor_idx;
         int active_er_period = MathMin(m_er_period, elapsed_bars);

         // Calculate Efficiency Ratio (ER)
         double direction = MathAbs(m_price[i] - m_price[i - active_er_period]);
         double volatility = 0.0;

         for(int j = 0; j < active_er_period; j++)
           {
            volatility += MathAbs(m_price[i - j] - m_price[i - j - 1]);
           }

         double er = (volatility > 0.000001) ? direction / volatility : 0;

         // Calculate Scaled Smoothing Constant (SSC)
         double sc = pow(er * (m_fastest_sc - m_slowest_sc) + m_slowest_sc, 2);

         // Calculate Final AMA (KAMA) into internal state buffer (FIXED: Corrected array names)
         m_kama_internal[i] = m_kama_internal[i-1] + sc * (m_price[i] - m_kama_internal[i-1]);
        }

      // Map to separate buffers based on period parity to create a clean gap
      if(current_period_idx % 2 != 0)
        {
         kama_odd[i] = m_kama_internal[i];
         kama_even[i] = EMPTY_VALUE;
        }
      else
        {
         kama_even[i] = m_kama_internal[i];
         kama_odd[i] = EMPTY_VALUE;
        }
     }
  }

//+==================================================================+
//|             CLASS 2: CKamaAnchoredCalculator_HA                  |
//+==================================================================+
class CKamaAnchoredCalculator_HA : public CKamaAnchoredCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CKamaAnchoredCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
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
            m_price[i] = (m_ha_high[i]+m_ha_low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+m_ha_close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+2*m_ha_close[i])/4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }

#endif // KAMA_ANCHORED_CALCULATOR_MQH
//+------------------------------------------------------------------+
