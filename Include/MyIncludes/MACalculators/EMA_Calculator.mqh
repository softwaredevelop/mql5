//+------------------------------------------------------------------+
//|                                               EMA_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#ifndef EMA_CALCULATOR_MQH
#define EMA_CALCULATOR_MQH

#include <MyIncludes\MACalculators\Base_Calculator.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CEMACalculator : public CBaseMACalculator
  {
protected:
   double            m_alpha;
   double            m_beta;

public:
   virtual bool      Init(const int period) override
     {
      if(!CBaseMACalculator::Init(period))
         return false;
      m_alpha = 2.0 / (double)(m_period + 1.0);
      m_beta  = 1.0 - m_alpha;
      return true;
     }

   virtual void      Calculate(const int rates_total,
                               const int start_index,
                               const double &price[],
                               const double &volume[],
                               double &output[],
                               const int data_offset = 0) override
     {
      int start_pos = data_offset + m_period - 1;
      if(rates_total <= start_pos)
         return;

      int loop_start = MathMax(start_pos, start_index);

      for(int i = loop_start; i < rates_total; i++)
        {
         bool has_valid_prev = (i > start_pos && output[i - 1] != EMPTY_VALUE && output[i - 1] != 0.0);

         if(has_valid_prev)
           {
            if(price[i] != EMPTY_VALUE)
               output[i] = price[i] * m_alpha + output[i - 1] * m_beta;
            else
               output[i] = output[i - 1];
           }
         else
           {
            if(i < start_pos)
              {
               output[i] = EMPTY_VALUE;
               continue;
              }
            double sum = 0.0;
            int count = 0;
            for(int j = 0; j < m_period; j++)
              {
               if(price[i - j] != EMPTY_VALUE)
                 {
                  sum += price[i - j];
                  count++;
                 }
              }
            output[i] = (count > 0) ? (sum / (double)count) : price[i];
           }
        }
     }
  };

#endif // EMA_CALCULATOR_MQH
//+------------------------------------------------------------------+
