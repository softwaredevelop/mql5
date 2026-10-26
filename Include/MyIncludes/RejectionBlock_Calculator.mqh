//+------------------------------------------------------------------+
//|                                RejectionBlock_Calculator.mqh     |
//|        Headless Engine for Institutional Rejection Blocks        |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.10" // Enterprise Edition: Pure Price-Action Wicks, Embedded ATR & Zero-Heap Execution
#property description "Mathematical engine for Rejection Wicks, Liquidity Sweeps, and Order Block tracking."

#ifndef REJECTION_BLOCK_CALCULATOR_MQH
#define REJECTION_BLOCK_CALCULATOR_MQH

#include <MyIncludes\ATR_Calculator.mqh>

//--- Structure for Tracking Rejection Block Lifecycle
struct SRejectionBlock
  {
   int               id;
   datetime          time_start;
   datetime          time_end;
   double            top;
   double            bottom;
   double            mid;
   bool              is_bull;
   int               bar_formed;
   bool              armed;
   bool              touched;
   bool              invalidated;
   datetime          time_invalidated;
  };

//+==================================================================+
//|   CLASS: CRejectionBlock_Calculator                              |
//+==================================================================+
class CRejectionBlock_Calculator
  {
private:
   int               m_swing_len;
   double            m_min_wick_pct;
   double            m_wick_atr_mult;
   int               m_atr_len;
   bool              m_sweep_filter;
   int               m_max_blocks;

   // Embedded Calculation Engine
   CATRCalculator    *m_atr_engine;

   // Persistent Working Buffers
   double            m_atr_buffer[];
   SRejectionBlock   m_blocks[];
   int               m_block_count;
   int               m_id_counter;

   double            m_last_swing_high;
   double            m_last_swing_low;

   void              AddBlock(const double zone_top, const double zone_bottom, const bool is_bull,
                              const datetime start_time, const datetime end_time, const int bar_idx);

public:
                     CRejectionBlock_Calculator(void);
                    ~CRejectionBlock_Calculator(void);

   bool              Init(const int swing_len, const double min_wick_pct, const double wick_atr_mult,
                          const int atr_len, const bool sweep_filter, const int max_blocks);

   void              Calculate(const int rates_total, const int prev_calculated,
                               const datetime &time[], const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               double &out_bull_sig[], double &out_bear_sig[]);

   int               GetBlockCount(void) const { return m_block_count; }
   bool              GetBlock(const int index, SRejectionBlock &out_block) const;
   void              Reset(void);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRejectionBlock_Calculator::CRejectionBlock_Calculator(void) :
   m_swing_len(10),
   m_min_wick_pct(50.0),
   m_wick_atr_mult(0.5),
   m_atr_len(14),
   m_sweep_filter(false),
   m_max_blocks(10),
   m_atr_engine(NULL),
   m_block_count(0),
   m_id_counter(0),
   m_last_swing_high(WRONG_VALUE),
   m_last_swing_low(WRONG_VALUE)
  {
   ArraySetAsSeries(m_atr_buffer, false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRejectionBlock_Calculator::~CRejectionBlock_Calculator(void)
  {
   if(CheckPointer(m_atr_engine) != POINTER_INVALID)
     {
      delete m_atr_engine;
      m_atr_engine = NULL;
     }
   ArrayFree(m_atr_buffer);
   ArrayFree(m_blocks);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CRejectionBlock_Calculator::Init(const int swing_len, const double min_wick_pct, const double wick_atr_mult,
                                      const int atr_len, const bool sweep_filter, const int max_blocks)
  {
   m_swing_len     = (swing_len < 1) ? 1 : swing_len;
   m_min_wick_pct  = (min_wick_pct < 0.0) ? 0.0 : min_wick_pct;
   m_wick_atr_mult = (wick_atr_mult < 0.0) ? 0.0 : wick_atr_mult;
   m_atr_len       = (atr_len < 1) ? 14 : atr_len;
   m_sweep_filter  = sweep_filter;
   m_max_blocks    = (max_blocks < 1) ? 10 : max_blocks;

   if(CheckPointer(m_atr_engine) != POINTER_INVALID)
      delete m_atr_engine;

   m_atr_engine = new CATRCalculator();
   if(CheckPointer(m_atr_engine) == POINTER_INVALID || !m_atr_engine.Init(m_atr_len, ATR_POINTS))
      return false;

   Reset();
   return true;
  }

//+------------------------------------------------------------------+
//| Reset Internal State                                             |
//+------------------------------------------------------------------+
void CRejectionBlock_Calculator::Reset(void)
  {
   m_block_count     = 0;
   m_id_counter      = 0;
   m_last_swing_high = WRONG_VALUE;
   m_last_swing_low  = WRONG_VALUE;
   ArrayResize(m_blocks, 0);
  }

//+------------------------------------------------------------------+
//| Internal: Add New Block to Ring Buffer Pool                      |
//+------------------------------------------------------------------+
void CRejectionBlock_Calculator::AddBlock(const double zone_top, const double zone_bottom, const bool is_bull,
      const datetime start_time, const datetime end_time, const int bar_idx)
  {
   m_id_counter++;
   int size = m_block_count;
   ArrayResize(m_blocks, size + 1);

   m_blocks[size].id               = m_id_counter;
   m_blocks[size].time_start       = start_time;
   m_blocks[size].time_end         = end_time;
   m_blocks[size].top              = zone_top;
   m_blocks[size].bottom           = zone_bottom;
   m_blocks[size].mid              = (zone_top + zone_bottom) * 0.5;
   m_blocks[size].is_bull          = is_bull;
   m_blocks[size].bar_formed       = bar_idx;
   m_blocks[size].armed            = false;
   m_blocks[size].touched          = false;
   m_blocks[size].invalidated      = false;
   m_blocks[size].time_invalidated = 0;

   m_block_count++;

// Maintain user maximum limit (FIFO Ring eviction)
   if(m_block_count > m_max_blocks)
     {
      for(int j = 0; j < m_block_count - 1; j++)
         m_blocks[j] = m_blocks[j + 1];

      m_block_count--;
      ArrayResize(m_blocks, m_block_count);
     }
  }

//+------------------------------------------------------------------+
//| Main Incremental Execution Loop                                  |
//+------------------------------------------------------------------+
void CRejectionBlock_Calculator::Calculate(const int rates_total, const int prev_calculated,
      const datetime &time[], const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &out_bull_sig[], double &out_bear_sig[])
  {
   int L = m_swing_len;
   int min_bars = MathMax(L * 2 + 1, m_atr_len + 2);
   if(rates_total < min_bars || !m_atr_engine)
      return;

// 1. Calculate Pipelined ATR Baseline
   m_atr_engine.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

   int start = (prev_calculated > 0) ? (prev_calculated - 1) : (2 * L);
   if(prev_calculated == 0)
     {
      Reset();
      for(int i = 0; i < rates_total; i++)
        {
         out_bull_sig[i] = EMPTY_VALUE;
         out_bear_sig[i] = EMPTY_VALUE;
        }
     }

   datetime curr_time = time[rates_total - 1];

// 2. Main Sequential Evaluation
   for(int i = start; i < rates_total; i++)
     {
      out_bull_sig[i] = EMPTY_VALUE;
      out_bear_sig[i] = EMPTY_VALUE;

      bool is_confirmed = (i < rates_total - 1);
      int p = i - L; // Pivot candidate index

      if(is_confirmed && p >= L)
        {
         // A) Swing High Rejection Wick Inspection
         bool is_p_high = true;
         double p_hi = high[p];
         for(int j = 1; j <= L; j++)
           {
            if(high[p - j] >= p_hi || high[p + j] >= p_hi)
              {
               is_p_high = false;
               break;
              }
           }

         if(is_p_high)
           {
            double range     = high[p] - low[p];
            double body_top  = MathMax(open[p], close[p]);
            double upper_wick= high[p] - body_top;
            double atr_val   = m_atr_buffer[p];

            bool wick_pct_ok = (upper_wick > 0.0 && range > 0.0 && (upper_wick / range * 100.0) >= m_min_wick_pct);
            bool wick_atr_ok = (m_wick_atr_mult == 0.0 || upper_wick >= m_wick_atr_mult * atr_val);
            bool sweep_ok    = (!m_sweep_filter || (m_last_swing_high != WRONG_VALUE && high[p] > m_last_swing_high && close[p] < m_last_swing_high));

            if(wick_pct_ok && wick_atr_ok && sweep_ok)
              {
               AddBlock(high[p], body_top, false, time[p], time[i], i);
               out_bear_sig[i] = high[p] + (atr_val * 0.3); // Signal Arrow
              }

            m_last_swing_high = high[p];
           }

         // B) Swing Low Rejection Wick Inspection
         bool is_p_low = true;
         double p_lo = low[p];
         for(int j = 1; j <= L; j++)
           {
            if(low[p - j] <= p_lo || low[p + j] <= p_lo)
              {
               is_p_low = false;
               break;
              }
           }

         if(is_p_low)
           {
            double range       = high[p] - low[p];
            double body_bottom = MathMin(open[p], close[p]);
            double lower_wick  = body_bottom - low[p];
            double atr_val     = m_atr_buffer[p];

            bool wick_pct_ok = (lower_wick > 0.0 && range > 0.0 && (lower_wick / range * 100.0) >= m_min_wick_pct);
            bool wick_atr_ok = (m_wick_atr_mult == 0.0 || lower_wick >= m_wick_atr_mult * atr_val);
            bool sweep_ok    = (!m_sweep_filter || (m_last_swing_low != WRONG_VALUE && low[p] < m_last_swing_low && close[p] > m_last_swing_low));

            if(wick_pct_ok && wick_atr_ok && sweep_ok)
              {
               AddBlock(body_bottom, low[p], true, time[p], time[i], i);
               out_bull_sig[i] = low[p] - (atr_val * 0.3); // Signal Arrow
              }

            m_last_swing_low = low[p];
           }
        }

      // 3. Stateful Block Lifecycle Updates (Invalidation, Retest, Extension)
      for(int b = 0; b < m_block_count; b++)
        {
         if(!m_blocks[b].invalidated)
           {
            datetime extend_to = (i == rates_total - 1) ? curr_time : time[i];
            m_blocks[b].time_end = extend_to;

            if(is_confirmed && i > m_blocks[b].bar_formed)
              {
               // Invalidation rule: Candle body closes completely beyond the rejection wick boundary
               bool breached = m_blocks[b].is_bull ? (close[i] < m_blocks[b].bottom) : (close[i] > m_blocks[b].top);

               if(breached)
                 {
                  m_blocks[b].invalidated      = true;
                  m_blocks[b].time_invalidated = time[i];
                  m_blocks[b].time_end         = time[i]; // Strict Truncation!
                 }
               else
                  if(!m_blocks[b].armed)
                    {
                     // Arming: Price fully leaves the rejection wick zone
                     m_blocks[b].armed = m_blocks[b].is_bull ? (low[i] > m_blocks[b].top) : (high[i] < m_blocks[b].bottom);
                    }
                  else
                     if(!m_blocks[b].touched)
                       {
                        // Retest: Price returns back inside the zone
                        bool back_in = m_blocks[b].is_bull ? (low[i] <= m_blocks[b].top) : (high[i] >= m_blocks[b].bottom);
                        if(back_in)
                           m_blocks[b].touched = true;
                       }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Accessor                                                         |
//+------------------------------------------------------------------+
bool CRejectionBlock_Calculator::GetBlock(const int index, SRejectionBlock &out_block) const
  {
   if(index >= 0 && index < m_block_count)
     {
      out_block = m_blocks[index];
      return true;
     }
   return false;
  }

#endif // REJECTION_BLOCK_CALCULATOR_MQH
//+------------------------------------------------------------------+
