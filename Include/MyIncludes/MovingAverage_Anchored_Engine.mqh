//+------------------------------------------------------------------+
//|                                  MovingAverage_Anchored_Engine.mqh|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.27" // Standardized state safety and dynamic array index guards
#property description "Perry Kaufman & Welles Wilder Dynamic Anchored MA Engine."

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
   ANCHOR_SESSION,        // Reset every day (Daily VWAP style)
   ANCHOR_WEEK,           // Reset every week (Weekly VWAP style)
   ANCHOR_MONTH,          // Reset every month (Monthly VWAP style)
   ANCHOR_CUSTOM_SESSION  // Reset based on custom broker-time range
  };
#endif

//+==================================================================+
//|             CLASS 1: CMovingAverageAnchoredCalculator            |
//+==================================================================+
class CMovingAverageAnchoredCalculator
  {
protected:
   int               m_period;
   ENUM_MA_TYPE      m_ma_type;
   ENUM_ANCHOR_PERIOD m_anchor;

   //--- Dynamic pricing & volume buffers
   double                    m_price[];
   double                    m_volume[];
   double                    m_ma_internal[];  // Seamless internal continuous MA state buffer
   int                       m_anchor_start[]; // Stateful anchor start tracker per bar
   int                       m_period_idx[];   // Stateful session index tracker (odd/even) per bar

   //--- Temp buffers for dynamic DEMA/TEMA/TMA calculations
   double                    m_temp_ema1[];
   double                    m_temp_ema2[];
   double                    m_temp_ema3[];

   // Custom session times
   int               m_start_hour, m_start_min;
   int               m_end_hour, m_end_min;

   bool              IsTimeInSession(datetime time_val);
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

   // Helper for dynamic EMA calculation on any array (O(1) complexity)
   double            CalculateDynamicEMA(int idx, int active_p, double val, double &ema_array[]);

public:
                     CMovingAverageAnchoredCalculator(void);
   virtual          ~CMovingAverageAnchoredCalculator(void) {};

   bool              Init(int period, ENUM_MA_TYPE ma_type, ENUM_ANCHOR_PERIOD anchor, string custom_start="09:00", string custom_end="18:00");

   //--- Standard Calculate with Gapped Segments (Odd & Even)
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const datetime &time[],
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &ma_odd[], double &ma_even[]);

   //--- Overloaded Calculate with Volume and Gapped Segments (for VWMA support)
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const datetime &time[],
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &volume[],
                               double &ma_odd[], double &ma_even[]);

   //--- Standard Calculate with Continuous output (No Gaps - needed for Z-Score mean baseline)
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const datetime &time[],
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &ma_buffer[]);

   //--- Overloaded Calculate with Volume and Continuous output (for VWMA baseline support)
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const datetime &time[],
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &volume[],
                               double &ma_buffer[]);

   //--- Getter for anchor start index (O(1) complexity)
   int               GetAnchorStart(int index) const { return m_anchor_start[index]; }
   int               GetPeriod(void) const { return m_period; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMovingAverageAnchoredCalculator::CMovingAverageAnchoredCalculator(void) :
   m_period(20), m_ma_type(SMA), m_anchor(ANCHOR_SESSION), m_start_hour(9), m_start_min(0), m_end_hour(18), m_end_min(0)
  {
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMovingAverageAnchoredCalculator::Init(int period, ENUM_MA_TYPE ma_type, ENUM_ANCHOR_PERIOD anchor, string custom_start, string custom_end)
  {
   m_period  = (period < 1) ? 1 : period;
   m_ma_type = ma_type;
   m_anchor  = anchor;

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
bool CMovingAverageAnchoredCalculator::IsTimeInSession(datetime time_val)
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
//| Calculate EMA on the fly (Dynamic smoothing constant)            |
//+------------------------------------------------------------------+
double CMovingAverageAnchoredCalculator::CalculateDynamicEMA(int idx, int active_p, double val, double &ema_array[])
  {
   double pr = 2.0 / (double)(active_p + 1.0);
   if(idx == m_anchor_start[idx] || ema_array[idx-1] == EMPTY_VALUE)
      ema_array[idx] = val;
   else
      ema_array[idx] = val * pr + ema_array[idx-1] * (1.0 - pr);
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
//| Calculate (Segmented - Overloaded - With Volume for VWMA)        |
//+------------------------------------------------------------------+
void CMovingAverageAnchoredCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const datetime &time[],
      const double &open[], const double &high[], const double &low[], const double &close[],
      const long &volume[],
      double &ma_odd[], double &ma_even[])
  {
   if(rates_total < m_period)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_volume, rates_total);
      ArrayResize(m_ma_internal, rates_total);
      ArrayResize(m_anchor_start, rates_total);
      ArrayResize(m_period_idx, rates_total);
      ArrayResize(m_temp_ema1, rates_total);
      ArrayResize(m_temp_ema2, rates_total);
      ArrayResize(m_temp_ema3, rates_total);

      ArraySetAsSeries(m_price, false);
      ArraySetAsSeries(m_volume, false);
      ArraySetAsSeries(m_ma_internal, false);
      ArraySetAsSeries(m_anchor_start, false);
      ArraySetAsSeries(m_period_idx, false);
      ArraySetAsSeries(m_temp_ema1, false);
      ArraySetAsSeries(m_temp_ema2, false);
      ArraySetAsSeries(m_temp_ema3, false);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   for(int i = start_index; i < rates_total; i++)
      m_volume[i] = (double)volume[i];

   if(start_index == 0)
     {
      m_anchor_start[0] = 0;
      m_period_idx[0] = 1;
      m_ma_internal[0] = m_price[0];
      m_temp_ema1[0] = m_price[0];
      m_temp_ema2[0] = m_price[0];
      m_temp_ema3[0] = m_price[0];
      ma_odd[0] = m_price[0];
      ma_even[0] = EMPTY_VALUE;
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

      if(i == current_anchor_idx)
        {
         m_ma_internal[i] = m_price[i];
         m_temp_ema1[i] = m_price[i];
         m_temp_ema2[i] = m_price[i];
         m_temp_ema3[i] = m_price[i];
        }
      else
        {
         int elapsed_bars = i - current_anchor_idx + 1;
         int active_p = MathMin(m_period, elapsed_bars);

         switch(m_ma_type)
           {
            case EMA:
              {
               m_ma_internal[i] = CalculateDynamicEMA(i, active_p, m_price[i], m_temp_ema1);
               break;
              }
            case SMMA:
              {
               double pr = 1.0 / (double)active_p;
               m_ma_internal[i] = m_price[i] * pr + m_ma_internal[i-1] * (1.0 - pr);
               break;
              }
            case LWMA:
              {
               double sum = 0, w_sum = 0;
               for(int k = 0; k < active_p; k++)
                 {
                  int w = active_p - k;
                  sum += m_price[i-k] * w;
                  w_sum += w;
                 }
               m_ma_internal[i] = (w_sum > 0) ? (sum / w_sum) : m_price[i];
               break;
              }
            case TMA:
              {
               int period1 = (int)ceil((active_p + 1.0) / 2.0);
               double sum_tp = 0;
               int count_tp = 0;
               for(int j = 0; j < period1; j++)
                 {
                  sum_tp += m_price[i-j];
                  count_tp++;
                 }
               m_temp_ema1[i] = (count_tp > 0) ? (sum_tp / count_tp) : m_price[i];

               int period2 = active_p - period1 + 1;
               double sum_f = 0;
               int count_f = 0;
               for(int j = 0; j < period2; j++)
                 {
                  sum_f += m_temp_ema1[i-j];
                  count_f++;
                 }
               m_ma_internal[i] = (count_f > 0) ? (sum_f / count_f) : m_temp_ema1[i];
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
               double sum_pv = 0, sum_v = 0;
               for(int k = 0; k < active_p; k++)
                 {
                  sum_pv += m_price[i-k] * m_volume[i-k];
                  sum_v  += m_volume[i-k];
                 }
               m_ma_internal[i] = (sum_v > 0) ? (sum_pv / sum_v) : m_price[i];
               break;
              }
            default: // SMA
              {
               double sum = 0;
               for(int k = 0; k < active_p; k++)
                  sum += m_price[i-k];
               m_ma_internal[i] = sum / active_p;
               break;
              }
           }
        }

      // Segmented Odd vs Even Parity Output
      if(current_period_idx % 2 != 0)
        {
         ma_odd[i] = m_ma_internal[i];
         ma_even[i] = EMPTY_VALUE;
        }
      else
        {
         ma_even[i] = m_ma_internal[i];
         ma_odd[i] = EMPTY_VALUE;
        }
     }
  }

//+------------------------------------------------------------------+
//| NEW OVERLOAD: Calculate (Continuous - Standard - No Volume)       |
//+------------------------------------------------------------------+
void CMovingAverageAnchoredCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const datetime &time[],
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &ma_buffer[])
  {
   long dummy_vol[];
   ArrayResize(dummy_vol, rates_total);
   ArrayInitialize(dummy_vol, 1);
   Calculate(rates_total, prev_calculated, price_type, time, open, high, low, close, dummy_vol, ma_buffer);
  }

//+------------------------------------------------------------------+
//| NEW OVERLOAD: Calculate (Continuous - With Volume)              |
//+------------------------------------------------------------------+
void CMovingAverageAnchoredCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const datetime &time[],
      const double &open[], const double &high[], const double &low[], const double &close[],
      const long &volume[],
      double &ma_buffer[])
  {
   if(rates_total < m_period)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_volume, rates_total);
      ArrayResize(m_ma_internal, rates_total);
      ArrayResize(m_anchor_start, rates_total);
      ArrayResize(m_period_idx, rates_total);
      ArrayResize(m_temp_ema1, rates_total);
      ArrayResize(m_temp_ema2, rates_total);
      ArrayResize(m_temp_ema3, rates_total);

      ArraySetAsSeries(m_price, false);
      ArraySetAsSeries(m_volume, false);
      ArraySetAsSeries(m_ma_internal, false);
      ArraySetAsSeries(m_anchor_start, false);
      ArraySetAsSeries(m_period_idx, false);
      ArraySetAsSeries(m_temp_ema1, false);
      ArraySetAsSeries(m_temp_ema2, false);
      ArraySetAsSeries(m_temp_ema3, false);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   for(int i = start_index; i < rates_total; i++)
      m_volume[i] = (double)volume[i];

   if(start_index == 0)
     {
      m_anchor_start[0] = 0;
      m_period_idx[0] = 1;
      m_ma_internal[0] = m_price[0];
      m_temp_ema1[0] = m_price[0];
      m_temp_ema2[0] = m_price[0];
      m_temp_ema3[0] = m_price[0];
      ma_buffer[0] = m_price[0];
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

      if(i == current_anchor_idx)
        {
         m_ma_internal[i] = m_price[i];
         m_temp_ema1[i] = m_price[i];
         m_temp_ema2[i] = m_price[i];
         m_temp_ema3[i] = m_price[i];
        }
      else
        {
         int elapsed_bars = i - current_anchor_idx + 1;
         int active_p = MathMin(m_period, elapsed_bars);

         switch(m_ma_type)
           {
            case EMA:
              {
               m_ma_internal[i] = CalculateDynamicEMA(i, active_p, m_price[i], m_temp_ema1);
               break;
              }
            case SMMA:
              {
               double pr = 1.0 / (double)active_p;
               m_ma_internal[i] = m_price[i] * pr + m_ma_internal[i-1] * (1.0 - pr);
               break;
              }
            case LWMA:
              {
               double sum = 0, w_sum = 0;
               for(int k = 0; k < active_p; k++)
                 {
                  int w = active_p - k;
                  sum += m_price[i-k] * w;
                  w_sum += w;
                 }
               m_ma_internal[i] = (w_sum > 0) ? (sum / w_sum) : m_price[i];
               break;
              }
            case TMA:
              {
               int period1 = (int)ceil((active_p + 1.0) / 2.0);
               double sum_tp = 0;
               int count_tp = 0;
               for(int j = 0; j < period1; j++)
                 {
                  sum_tp += m_price[i-j];
                  count_tp++;
                 }
               m_temp_ema1[i] = (count_tp > 0) ? (sum_tp / count_tp) : m_price[i];

               int period2 = active_p - period1 + 1;
               double sum_f = 0;
               int count_f = 0;
               for(int j = 0; j < period2; j++)
                 {
                  sum_f += m_temp_ema1[i-j];
                  count_f++;
                 }
               m_ma_internal[i] = (count_f > 0) ? (sum_f / count_f) : m_temp_ema1[i];
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
               double sum_pv = 0, sum_v = 0;
               for(int k = 0; k < active_p; k++)
                 {
                  sum_pv += m_price[i-k] * m_volume[i-k];
                  sum_v  += m_volume[i-k];
                 }
               m_ma_internal[i] = (sum_v > 0) ? (sum_pv / sum_v) : m_price[i];
               break;
              }
            default: // SMA
              {
               double sum = 0;
               for(int k = 0; k < active_p; k++)
                  sum += m_price[i-k];
               m_ma_internal[i] = sum / active_p;
               break;
              }
           }
        }

      ma_buffer[i] = m_ma_internal[i];
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CMovingAverageAnchoredCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (high[i]+low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
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
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CMovingAverageAnchoredCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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

#endif // MOVING_AVERAGE_ANCHORED_ENGINE_MQH
//+------------------------------------------------------------------+
