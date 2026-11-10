//+------------------------------------------------------------------+
//|                                            Divergence_Engine.mqh |
//|           Universal Multi-Oscillator Divergence DSP Engine       |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property library

#ifndef DIVERGENCE_ENGINE_MQH
#define DIVERGENCE_ENGINE_MQH

//--- Divergence Classification Enum
enum ENUM_DIVERGENCE_TYPE
  {
   DIV_NONE,
   DIV_REGULAR_BULLISH,      // Reversal: Lower Low in Price + Higher Low in Osc
   DIV_REGULAR_BEARISH,      // Reversal: Higher High in Price + Lower High in Osc
   DIV_HIDDEN_BULLISH,       // Continuation: Higher Low in Price + Lower Low in Osc
   DIV_HIDDEN_BEARISH        // Continuation: Lower High in Price + Higher High in Osc
  };

//--- Divergence Mode Filter
enum ENUM_DIV_FILTER_MODE
  {
   DIV_FILTER_REGULAR_ONLY,  // Regular (Reversal) Divergences Only
   DIV_FILTER_HIDDEN_ONLY,   // Hidden (Trend Continuation) Only
   DIV_FILTER_BOTH           // Both Regular and Hidden
  };

//--- Structure representing a confirmed Pivot Point
struct SPivotPoint
  {
   int               bar_index;      // Bar index where pivot occurred
   datetime          time;           // Timestamp of the pivot
   double            price;          // Price at the pivot (High or Low)
   double            osc_value;      // Oscillator value at the pivot
   bool              is_high;        // True = Peak (High), False = Valley (Low)
  };

//--- Structure representing a verified Divergence Event
struct SDivergenceEvent
  {
   ENUM_DIVERGENCE_TYPE type;
   int               confirm_bar;    // Bar where divergence was confirmed (Right bars confirmed)
   datetime          confirm_time;
   SPivotPoint       prev_pivot;     // Historical reference pivot
   SPivotPoint       curr_pivot;     // Newly confirmed pivot
  };

//+------------------------------------------------------------------+
//| CLASS: CDivergenceEngine                                         |
//+------------------------------------------------------------------+
class CDivergenceEngine
  {
private:
   int                  m_left_bars;
   int                  m_right_bars;
   int                  m_min_distance;
   int                  m_max_distance;
   ENUM_DIV_FILTER_MODE m_filter_mode;

   //--- Persistent Pivot History Registers
   SPivotPoint          m_high_pivots[];
   SPivotPoint          m_low_pivots[];
   int                  m_high_pivots_count;
   int                  m_low_pivots_count;

   bool                 IsOscHighPivot(const int bar, const double &osc[], const int rates_total) const;
   bool                 IsOscLowPivot(const int bar, const double &osc[], const int rates_total) const;

public:
                     CDivergenceEngine(void);
                    ~CDivergenceEngine(void) {}

   bool                 Init(const int left_bars,
                             const int right_bars,
                             const int min_distance,
                             const int max_distance,
                             const ENUM_DIV_FILTER_MODE filter_mode);

   void                 Reset(void);

   //--- Core Scan Pipeline
   bool                 ProcessBar(const int current_bar,
                                   const int rates_total,
                                   const datetime &time[],
                                   const double &high[],
                                   const double &low[],
                                   const double &osc[],
                                   SDivergenceEvent &out_event);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CDivergenceEngine::CDivergenceEngine(void) : m_left_bars(3),
   m_right_bars(2),
   m_min_distance(5),
   m_max_distance(60),
   m_filter_mode(DIV_FILTER_BOTH),
   m_high_pivots_count(0),
   m_low_pivots_count(0)
  {
   ArraySetAsSeries(m_high_pivots, false);
   ArraySetAsSeries(m_low_pivots,  false);
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CDivergenceEngine::Init(const int left_bars,
                             const int right_bars,
                             const int min_distance,
                             const int max_distance,
                             const ENUM_DIV_FILTER_MODE filter_mode)
  {
   m_left_bars    = MathMax(1, left_bars);
   m_right_bars   = MathMax(1, right_bars);
   m_min_distance = MathMax(2, min_distance);
   m_max_distance = MathMax(m_min_distance + 1, max_distance);
   m_filter_mode  = filter_mode;

   Reset();
   return true;
  }

//+------------------------------------------------------------------+
//| Reset                                                            |
//+------------------------------------------------------------------+
void CDivergenceEngine::Reset(void)
  {
   ArrayFree(m_high_pivots);
   ArrayFree(m_low_pivots);
   m_high_pivots_count = 0;
   m_low_pivots_count  = 0;
  }

//+------------------------------------------------------------------+
//| Verify Oscillator Local High Pivot Point                         |
//+------------------------------------------------------------------+
bool CDivergenceEngine::IsOscHighPivot(const int bar, const double &osc[], const int rates_total) const
  {
   if(bar - m_left_bars < 0 || bar + m_right_bars >= rates_total)
      return false;

   double val = osc[bar];
   if(val == EMPTY_VALUE)
      return false;

   for(int i = 1; i <= m_left_bars; i++)
     {
      if(osc[bar - i] >= val)
         return false;
     }

   for(int i = 1; i <= m_right_bars; i++)
     {
      if(osc[bar + i] > val)
         return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Verify Oscillator Local Low Pivot Point                          |
//+------------------------------------------------------------------+
bool CDivergenceEngine::IsOscLowPivot(const int bar, const double &osc[], const int rates_total) const
  {
   if(bar - m_left_bars < 0 || bar + m_right_bars >= rates_total)
      return false;

   double val = osc[bar];
   if(val == EMPTY_VALUE)
      return false;

   for(int i = 1; i <= m_left_bars; i++)
     {
      if(osc[bar - i] <= val)
         return false;
     }

   for(int i = 1; i <= m_right_bars; i++)
     {
      if(osc[bar + i] < val)
         return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Process Bar for Divergence Confirmation                          |
//+------------------------------------------------------------------+
bool CDivergenceEngine::ProcessBar(const int current_bar,
                                   const int rates_total,
                                   const datetime &time[],
                                   const double &high[],
                                   const double &low[],
                                   const double &osc[],
                                   SDivergenceEvent &out_event)
  {
   out_event.type = DIV_NONE;

// The pivot under inspection is located exactly m_right_bars in the past
   int p_bar = current_bar - m_right_bars;
   if(p_bar < m_left_bars)
      return false;

//================================================================
// 1. HIGH PIVOT (BEARISH DIVERGENCES)
//================================================================
   if(IsOscHighPivot(p_bar, osc, rates_total))
     {
      SPivotPoint curr;
      curr.bar_index = p_bar;
      curr.time      = time[p_bar];
      curr.price     = high[p_bar];
      curr.osc_value = osc[p_bar];
      curr.is_high   = true;

      if(m_high_pivots_count > 0)
        {
         SPivotPoint prev = m_high_pivots[m_high_pivots_count - 1];
         int distance = curr.bar_index - prev.bar_index;

         if(distance >= m_min_distance && distance <= m_max_distance)
           {
            // Regular Bearish: Higher High in Price, Lower High in Osc
            if(curr.price > prev.price && curr.osc_value < prev.osc_value)
              {
               if(m_filter_mode == DIV_FILTER_BOTH || m_filter_mode == DIV_FILTER_REGULAR_ONLY)
                 {
                  out_event.type         = DIV_REGULAR_BEARISH;
                  out_event.confirm_bar  = current_bar;
                  out_event.confirm_time = time[current_bar];
                  out_event.curr_pivot   = curr;
                  out_event.prev_pivot   = prev;
                 }
              }
            // Hidden Bearish: Lower High in Price, Higher High in Osc
            else
               if(curr.price < prev.price && curr.osc_value > prev.osc_value)
                 {
                  if(m_filter_mode == DIV_FILTER_BOTH || m_filter_mode == DIV_FILTER_HIDDEN_ONLY)
                    {
                     out_event.type         = DIV_HIDDEN_BEARISH;
                     out_event.confirm_bar  = current_bar;
                     out_event.confirm_time = time[current_bar];
                     out_event.curr_pivot   = curr;
                     out_event.prev_pivot   = prev;
                    }
                 }
           }
        }

      // Append verified pivot to state cache
      m_high_pivots_count++;
      ArrayResize(m_high_pivots, m_high_pivots_count, 128);
      m_high_pivots[m_high_pivots_count - 1] = curr;

      if(out_event.type != DIV_NONE)
         return true;
     }

//================================================================
// 2. LOW PIVOT (BULLISH DIVERGENCES)
//================================================================
   if(IsOscLowPivot(p_bar, osc, rates_total))
     {
      SPivotPoint curr;
      curr.bar_index = p_bar;
      curr.time      = time[p_bar];
      curr.price     = low[p_bar];
      curr.osc_value = osc[p_bar];
      curr.is_high   = false;

      if(m_low_pivots_count > 0)
        {
         SPivotPoint prev = m_low_pivots[m_low_pivots_count - 1];
         int distance = curr.bar_index - prev.bar_index;

         if(distance >= m_min_distance && distance <= m_max_distance)
           {
            // Regular Bullish: Lower Low in Price, Higher Low in Osc
            if(curr.price < prev.price && curr.osc_value > prev.osc_value)
              {
               if(m_filter_mode == DIV_FILTER_BOTH || m_filter_mode == DIV_FILTER_REGULAR_ONLY)
                 {
                  out_event.type         = DIV_REGULAR_BULLISH;
                  out_event.confirm_bar  = current_bar;
                  out_event.confirm_time = time[current_bar];
                  out_event.curr_pivot   = curr;
                  out_event.prev_pivot   = prev;
                 }
              }
            // Hidden Bullish: Higher Low in Price, Lower Low in Osc
            else
               if(curr.price > prev.price && curr.osc_value < prev.osc_value)
                 {
                  if(m_filter_mode == DIV_FILTER_BOTH || m_filter_mode == DIV_FILTER_HIDDEN_ONLY)
                    {
                     out_event.type         = DIV_HIDDEN_BULLISH;
                     out_event.confirm_bar  = current_bar;
                     out_event.confirm_time = time[current_bar];
                     out_event.curr_pivot   = curr;
                     out_event.prev_pivot   = prev;
                    }
                 }
           }
        }

      // Append verified pivot to state cache
      m_low_pivots_count++;
      ArrayResize(m_low_pivots, m_low_pivots_count, 128);
      m_low_pivots[m_low_pivots_count - 1] = curr;

      if(out_event.type != DIV_NONE)
         return true;
     }

   return false;
  }

#endif // DIVERGENCE_ENGINE_MQH
//+------------------------------------------------------------------+
