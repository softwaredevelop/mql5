//+------------------------------------------------------------------+
//|                                    KScore_Anchored_Calculator.mqh|
//|      Engine for Session-Anchored Kaufman Z-Score (AK-Score)      |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Fixed Dynamic Buffer Allocation & Bounds Protection

#ifndef KSCORE_ANCHORED_CALCULATOR_MQH
#define KSCORE_ANCHORED_CALCULATOR_MQH

#include <MyIncludes\KAMA_Anchored_Calculator.mqh>

//+==================================================================+
//|             CLASS: CKScoreAnchoredCalculator                     |
//+==================================================================+
class CKScoreAnchoredCalculator
  {
private:
   CKamaAnchoredCalculator m_akama_engine;

   //--- Persistent State Buffers
   double                  m_kama_odd[];
   double                  m_kama_even[];
   double                  m_price[];

public:
                     CKScoreAnchoredCalculator(void);
                    ~CKScoreAnchoredCalculator(void) {};

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
                                     double &out_akscore[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CKScoreAnchoredCalculator::CKScoreAnchoredCalculator(void)
  {
   ArraySetAsSeries(m_kama_odd,  false);
   ArraySetAsSeries(m_kama_even, false);
   ArraySetAsSeries(m_price,     false);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CKScoreAnchoredCalculator::Init(const ENUM_ANCHOR_PERIOD anchor_p,
                                     const int tz_shift_hours,
                                     const string custom_start,
                                     const string custom_end,
                                     const int er_p,
                                     const int fast_p,
                                     const int slow_p,
                                     const ENUM_APPLIED_PRICE_HA_ALL source)
  {
   return m_akama_engine.Init(anchor_p, tz_shift_hours, custom_start, custom_end,
                              er_p, fast_p, slow_p, source);
  }

//+------------------------------------------------------------------+
//| Main Incremental Calculation of Anchored K-Score                 |
//+------------------------------------------------------------------+
void CKScoreAnchoredCalculator::Calculate(const int rates_total,
      const int prev_calculated,
      const datetime &time[],
      const double &open[],
      const double &high[],
      const double &low[],
      const double &close[],
      double &out_akscore[])
  {
   if(rates_total < 2)
      return;

//--- Safe allocation of internal dynamic arrays before passing to engine
   if(ArraySize(m_kama_odd) != rates_total)
     {
      ArrayResize(m_kama_odd, rates_total);
      ArraySetAsSeries(m_kama_odd, false);
      ArrayInitialize(m_kama_odd, EMPTY_VALUE);
     }
   if(ArraySize(m_kama_even) != rates_total)
     {
      ArrayResize(m_kama_even, rates_total);
      ArraySetAsSeries(m_kama_even, false);
      ArrayInitialize(m_kama_even, EMPTY_VALUE);
     }
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false);
     }

//--- Safe allocation of caller output buffer if needed
   if(ArraySize(out_akscore) != rates_total)
     {
      ArrayResize(out_akscore, rates_total);
      ArraySetAsSeries(out_akscore, false);
      ArrayInitialize(out_akscore, 0.0);
     }

// 1. Run Underlying Anchored KAMA Engine
   m_akama_engine.Calculate(rates_total, prev_calculated, time, open, high, low, close,
                            m_kama_odd, m_kama_even, m_price);

// 2. Deterministic Intra-Session Variance and Z-Score Accumulation
   double sum_sq_dev       = 0.0;
   int    count            = 0;
   int    last_session_tag = 0; // 0=None, 1=Odd, 2=Even

   for(int i = 0; i < rates_total; i++)
     {
      bool is_odd  = (m_kama_odd[i]  != EMPTY_VALUE);
      bool is_even = (m_kama_even[i] != EMPTY_VALUE);

      if(!is_odd && !is_even)
        {
         // Gap between sessions
         last_session_tag = 0;
         sum_sq_dev = 0.0;
         count = 0;
         out_akscore[i] = 0.0;
         continue;
        }

      int session_tag = is_odd ? 1 : 2;
      if(session_tag != last_session_tag)
        {
         // Reset variance accumulator at new anchor session boundary
         sum_sq_dev = 0.0;
         count = 0;
         last_session_tag = session_tag;
        }

      double akama = is_odd ? m_kama_odd[i] : m_kama_even[i];

      if(akama > 0.0)
        {
         double diff = m_price[i] - akama;
         sum_sq_dev += (diff * diff);
         count++;

         double stddev = (count > 0) ? MathSqrt(sum_sq_dev / (double)count) : 0.0;

         if(stddev > 1.0e-9)
            out_akscore[i] = diff / stddev;
         else
            out_akscore[i] = 0.0; // Clean 0.0 at opening anchor bar
        }
      else
        {
         out_akscore[i] = 0.0;
        }
     }
  }

#endif // KSCORE_ANCHORED_CALCULATOR_MQH
//+------------------------------------------------------------------+
