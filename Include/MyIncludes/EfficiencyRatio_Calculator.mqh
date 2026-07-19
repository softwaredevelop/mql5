//+------------------------------------------------------------------+
//|                                EfficiencyRatio_Calculator.mqh    |
//|      Engine for Kaufman's Efficiency Ratio (ER).                 |
//|      Formula: Net Change / Sum of Changes.                       |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Refactored with strict chronological array safeguards

#ifndef EFFICIENCY_RATIO_CALCULATOR_MQH
#define EFFICIENCY_RATIO_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS: CEfficiencyRatioCalculator                    |
//+==================================================================+
class CEfficiencyRatioCalculator
  {
private:
   int               m_period;
   double            m_price[]; // Persistent price buffer

   bool              PreparePrice(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CEfficiencyRatioCalculator() {};
                    ~CEfficiencyRatioCalculator() {};

   bool              Init(int period);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               double &out_er[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CEfficiencyRatioCalculator::Init(int period)
  {
   m_period = (period < 1) ? 1 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CEfficiencyRatioCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &out_er[])
  {
   if(rates_total <= m_period)
      return;

//--- Enforce strict chronological safety on output array
   if(ArraySize(out_er) != rates_total)
     {
      ArrayResize(out_er, rates_total);
      ArraySetAsSeries(out_er, false);
     }

//--- Prepare internal price data
   int prepare_start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(!PreparePrice(rates_total, prepare_start, price_type, open, high, low, close))
      return;

//--- Incremental optimization loop
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : m_period;
   if(start_index < m_period)
     {
      for(int i = 0; i < m_period; i++)
         out_er[i] = 0.0;
      start_index = m_period;
     }

   for(int i = start_index; i < rates_total; i++)
     {
      double net_change = MathAbs(m_price[i] - m_price[i - m_period]);
      double sum_change = 0.0;

      // Sum absolute bar-to-bar changes over the period
      for(int k = 0; k < m_period; k++)
        {
         sum_change += MathAbs(m_price[i - k] - m_price[i - k - 1]);
        }

      if(sum_change > 1.0e-9)
         out_er[i] = net_change / sum_change;
      else
         out_er[i] = 0.0; // Default to 0.0 (unaligned / noisy flat market)
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price                                                    |
//+------------------------------------------------------------------+
bool CEfficiencyRatioCalculator::PreparePrice(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false);
     }

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
            m_price[i] = (high[i] + low[i]) * 0.5;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i] + low[i] + close[i] * 2.0) * 0.25;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

#endif // EFFICIENCY_RATIO_CALCULATOR_MQH
//+------------------------------------------------------------------+
