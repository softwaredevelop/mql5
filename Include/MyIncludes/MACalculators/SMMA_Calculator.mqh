//+------------------------------------------------------------------+
//|                                              SMMA_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#ifndef SMMA_CALCULATOR_MQH
#define SMMA_CALCULATOR_MQH

#include <MyIncludes\MACalculators\Base_Calculator.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CSMMACalculator : public CBaseMACalculator
  {
public:
   virtual void      Calculate(const int rates_total,
                               const int start_index,
                               const double &price[],
                               const double &volume[],
                               double &output[],
                               const int data_offset = 0) override
     {
      int start_pos  = data_offset + m_period - 1;
      int loop_start = MathMax(start_pos, start_index);
      double weight_prev = (double)(m_period - 1);

      for(int i = loop_start; i < rates_total; i++)
        {
         bool has_valid_prev = (i > start_pos && output[i - 1] != EMPTY_VALUE && output[i - 1] != 0.0);

         if(!has_valid_prev)
           {
            if(i < start_pos)
              {
               output[i] = EMPTY_VALUE;
               continue;
              }
            double sum = 0.0;
            for(int j = 0; j < m_period; j++)
               sum += price[i - j];
            output[i] = sum * m_inv_period;
           }
         else
           {
            output[i] = (output[i - 1] * weight_prev + price[i]) * m_inv_period;
           }
        }
     }
  };

#endif // SMMA_CALCULATOR_MQH
//+------------------------------------------------------------------+
