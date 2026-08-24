//+------------------------------------------------------------------+
//|                                             KScore_Calculator.mqh|
//|      Engine for Kaufman Adaptive Z-Score (K-Score) Calculation.  |
//|      Standard Deviation distance from KAMA in Sigma units.       |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Performance-optimized KAMA Z-Score Engine

#ifndef KSCORE_CALCULATOR_MQH
#define KSCORE_CALCULATOR_MQH

#include <MyIncludes\KAMA_Calculator.mqh>

//+==================================================================+
//|             CLASS: CKScoreCalculator                             |
//+==================================================================+
class CKScoreCalculator
  {
private:
   int                     m_er_period;
   int                     m_stdev_period;
   ENUM_APPLIED_PRICE_HA_ALL m_source_type;

   //--- Persistent State Buffers
   double                  m_price[];
   double                  m_kama_buffer[];
   double                  m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   //--- Composition Engines
   CKamaCalculator         m_kama_calc;
   CHeikinAshi_Calculator  m_ha_engine;

   //--- Internal Methods
   bool                    PreparePriceSeries(const int rates_total,
         const int start_index,
         const double &open[],
         const double &high[],
         const double &low[],
         const double &close[]);

public:
                     CKScoreCalculator(void);
                    ~CKScoreCalculator(void) {};

   bool                    Init(const int er_p, const int fast_p, const int slow_p, const int stdev_p, const ENUM_APPLIED_PRICE_HA_ALL source);
   int                     GetRequiredWarmup(void) const { return MathMax(m_er_period, m_stdev_period); }

   void                    Calculate(const int rates_total,
                                     const int prev_calculated,
                                     const double &open[],
                                     const double &high[],
                                     const double &low[],
                                     const double &close[],
                                     double &out_kscore[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CKScoreCalculator::CKScoreCalculator(void) : m_er_period(10),
   m_stdev_period(20),
   m_source_type(PRICE_CLOSE_STD)
  {
   ArraySetAsSeries(m_price, false);
   ArraySetAsSeries(m_kama_buffer, false);
   ArraySetAsSeries(m_ha_open, false);
   ArraySetAsSeries(m_ha_high, false);
   ArraySetAsSeries(m_ha_low, false);
   ArraySetAsSeries(m_ha_close, false);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CKScoreCalculator::Init(const int er_p, const int fast_p, const int slow_p, const int stdev_p, const ENUM_APPLIED_PRICE_HA_ALL source)
  {
   m_er_period    = (er_p < 1) ? 1 : er_p;
   m_stdev_period = (stdev_p < 2) ? 2 : stdev_p;
   m_source_type  = source;

   return m_kama_calc.Init(m_er_period, fast_p, slow_p, source);
  }

//+------------------------------------------------------------------+
//| Prepare Price Series (Standard / Heikin Ashi)                    |
//+------------------------------------------------------------------+
bool CKScoreCalculator::PreparePriceSeries(const int rates_total,
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
//| Main Incremental K-Score Calculation Loop                        |
//+------------------------------------------------------------------+
void CKScoreCalculator::Calculate(const int rates_total,
                                  const int prev_calculated,
                                  const double &open[],
                                  const double &high[],
                                  const double &low[],
                                  const double &close[],
                                  double &out_kscore[])
  {
   int warmup = GetRequiredWarmup();
   if(rates_total <= warmup)
      return;

   int start_prep = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// 1. Prepare Underlying Price Data
   if(!PreparePriceSeries(rates_total, start_prep, open, high, low, close))
      return;

// 2. Resize & Calculate KAMA Baseline
   if(ArraySize(m_kama_buffer) != rates_total)
     {
      ArrayResize(m_kama_buffer, rates_total);
      ArraySetAsSeries(m_kama_buffer, false);
     }

   m_kama_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_kama_buffer);

// 3. Clean invalid range on fresh run
   if(prev_calculated == 0)
     {
      for(int i = 0; i < warmup; i++)
         out_kscore[i] = 0.0;
     }

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : warmup;
   if(start_index < warmup)
      start_index = warmup;

// 4. Calculate K-Score (Standard Deviation Distance from KAMA)
   for(int i = start_index; i < rates_total; i++)
     {
      if(m_kama_buffer[i] == EMPTY_VALUE)
        {
         out_kscore[i] = 0.0;
         continue;
        }

      double sum_sq = 0.0;
      for(int k = 0; k < m_stdev_period; k++)
        {
         double diff = m_price[i - k] - m_kama_buffer[i];
         sum_sq += diff * diff;
        }

      double std_dev = MathSqrt(sum_sq / (double)m_stdev_period);

      if(std_dev > 1.0e-9)
         out_kscore[i] = (m_price[i] - m_kama_buffer[i]) / std_dev;
      else
         out_kscore[i] = 0.0;
     }
  }

#endif // KSCORE_CALCULATOR_MQH
//+------------------------------------------------------------------+
