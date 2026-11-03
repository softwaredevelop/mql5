//+------------------------------------------------------------------+
//|                                              LWMA_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#ifndef LWMA_CALCULATOR_MQH
#define LWMA_CALCULATOR_MQH

#include <MyIncludes\MACalculators\Base_Calculator.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CLWMACalculator : public CBaseMACalculator
  {
protected:
   double            m_inv_weight_sum;

public:
   virtual bool      Init(const int period) override
     {
      if(!CBaseMACalculator::Init(period))
         return false;
      double w_sum = (double)m_period * (double)(m_period + 1) * 0.5;
      m_inv_weight_sum = (w_sum > 0.0) ? (1.0 / w_sum) : 1.0;
      return true;
     }

   virtual void      Calculate(const int rates_total,
                               const int start_index,
                               const double &price[],
                               const double &volume[],
                               double &output[],
                               const int data_offset = 0) override
     {
      int start_pos  = data_offset + m_period - 1;
      int loop_start = MathMax(start_pos, start_index);

      for(int i = loop_start; i < rates_total; i++)
        {
         double sum = 0.0;
         for(int j = 0; j < m_period; j++)
            sum += price[i - j] * (double)(m_period - j);

         output[i] = sum * m_inv_weight_sum;
        }
     }
  };

#endif // LWMA_CALCULATOR_MQH
//+------------------------------------------------------------------+
