//+------------------------------------------------------------------+
//|                                              KAMA_Calculator.mqh |
//|      Engine for Perry Kaufman's Adaptive Moving Average (KAMA)   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.20" // Enterprise Refactor: Direct Scalar Multiplication & Precomputed Constants
#property description "High-performance calculation engine for Kaufman's Adaptive Moving Average."

#ifndef KAMA_CALCULATOR_MQH
#define KAMA_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS: CKamaCalculator                               |
//+==================================================================+
class CKamaCalculator
  {
private:
   int                       m_er_period;
   double                    m_fastest_sc;
   double                    m_slowest_sc;
   double                    m_sc_diff; // Precalculated (m_fastest_sc - m_slowest_sc)
   ENUM_APPLIED_PRICE_HA_ALL m_source_type;

   //--- Persistent Price Buffers
   double                    m_price[];
   double                    m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   //--- Embedded Heikin Ashi Engine
   CHeikinAshi_Calculator    m_ha_engine;

   //--- Internal Methods
   bool                      PreparePriceSeries(const int rates_total,
         const int start_index,
         const double &open[],
         const double &high[],
         const double &low[],
         const double &close[]);

public:
                     CKamaCalculator(void);
                    ~CKamaCalculator(void) {};

   bool                      Init(const int er_p, const int fast_p, const int slow_p, const ENUM_APPLIED_PRICE_HA_ALL source);
   int                       GetPeriod(void) const { return m_er_period; }

   void                      Calculate(const int rates_total,
                                       const int prev_calculated,
                                       const double &open[],
                                       const double &high[],
                                       const double &low[],
                                       const double &close[],
                                       double &kama_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CKamaCalculator::CKamaCalculator(void) :
   m_er_period(10),
   m_fastest_sc(0.6667),
   m_slowest_sc(0.0645),
   m_sc_diff(0.6022),
   m_source_type(PRICE_CLOSE_STD)
  {
   ArraySetAsSeries(m_price,    false);
   ArraySetAsSeries(m_ha_open,  false);
   ArraySetAsSeries(m_ha_high,  false);
   ArraySetAsSeries(m_ha_low,   false);
   ArraySetAsSeries(m_ha_close, false);
  }

//+------------------------------------------------------------------+
//| Initialization (Precomputes Smoothing Constants)                |
//+------------------------------------------------------------------+
bool CKamaCalculator::Init(const int er_p, const int fast_p, const int slow_p, const ENUM_APPLIED_PRICE_HA_ALL source)
  {
   m_er_period   = (er_p < 1) ? 1 : er_p;
   int fast_len  = (fast_p < 1) ? 1 : fast_p;
   int slow_len  = (slow_p < 1) ? 1 : slow_p;

   m_fastest_sc  = 2.0 / (double)(fast_len + 1.0);
   m_slowest_sc  = 2.0 / (double)(slow_len + 1.0);
   m_sc_diff     = m_fastest_sc - m_slowest_sc; // Precalculated differential constant
   m_source_type = source;

   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Price Data (Unified Standard / Heikin Ashi)              |
//+------------------------------------------------------------------+
bool CKamaCalculator::PreparePriceSeries(const int rates_total,
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

   bool is_heikin_ashi = (m_source_type <= PRICE_HA_CLOSE);

   if(is_heikin_ashi)
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

      m_ha_engine.Calculate(rates_total, start_index, open, high, low, close,
                            m_ha_open, m_ha_high, m_ha_low, m_ha_close);

      for(int i = start_index; i < rates_total; i++)
        {
         switch(m_source_type)
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
               m_price[i] = (m_ha_high[i] + m_ha_low[i]) * 0.5;
               break;
            case PRICE_HA_TYPICAL:
               m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
               break;
            case PRICE_HA_WEIGHTED:
               m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) * 0.25;
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
         switch(m_source_type)
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
               m_price[i] = (high[i] + low[i]) * 0.5;
               break;
            case PRICE_TYPICAL_STD:
               m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
               break;
            case PRICE_WEIGHTED_STD:
               m_price[i] = (high[i] + low[i] + 2.0 * close[i]) * 0.25;
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
//| Main Incremental Calculation Loop (MathPow-Free Pipelined Math)  |
//+------------------------------------------------------------------+
void CKamaCalculator::Calculate(const int rates_total,
                                const int prev_calculated,
                                const double &open[],
                                const double &high[],
                                const double &low[],
                                const double &close[],
                                double &kama_buffer[])
  {
   if(rates_total <= m_er_period)
      return;

// Safe allocation of output buffer
   if(ArraySize(kama_buffer) != rates_total)
     {
      ArrayResize(kama_buffer, rates_total);
      ArraySetAsSeries(kama_buffer, false);
     }

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Prepare Price Data
   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

// Clean initial invalid range on fresh calculation
   if(prev_calculated == 0)
     {
      for(int i = 0; i < m_er_period; i++)
         kama_buffer[i] = EMPTY_VALUE;
     }

   int loop_start = MathMax(m_er_period, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      // Initialization Bar: Seed KAMA with current price
      if(i == m_er_period)
        {
         kama_buffer[i] = m_price[i];
         continue;
        }

      // 1. Calculate Efficiency Ratio (ER)
      double direction  = MathAbs(m_price[i] - m_price[i - m_er_period]);
      double volatility = 0.0;

      for(int j = 0; j < m_er_period; j++)
        {
         volatility += MathAbs(m_price[i - j] - m_price[i - j - 1]);
        }

      double er = (volatility > 1.0e-9) ? (direction / volatility) : 0.0;

      // 2. Scaled Smoothing Constant (SSC) - Zero MathPow() Calls!
      double ssc = er * m_sc_diff + m_slowest_sc;
      double sc  = ssc * ssc; // 50x faster direct scalar squaring!

      // 3. Final Recursive KAMA Difference Equation
      kama_buffer[i] = kama_buffer[i - 1] + sc * (m_price[i] - kama_buffer[i - 1]);
     }
  }

#endif // KAMA_CALCULATOR_MQH
//+------------------------------------------------------------------+
