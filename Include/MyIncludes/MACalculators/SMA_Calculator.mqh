//+------------------------------------------------------------------+
//|                                               SMA_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#ifndef SMA_CALCULATOR_MQH
#define SMA_CALCULATOR_MQH

#include <MyIncludes\MACalculators\Base_Calculator.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CSMACalculator : public CBaseMACalculator
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

      for(int i = loop_start; i < rates_total; i++)
        {
         double sum = 0.0;
         for(int j = 0; j < m_period; j++)
            sum += price[i - j];
         output[i] = sum * m_inv_period;
        }
     }
  };

#endif // SMA_CALCULATOR_MQH
//+------------------------------------------------------------------+
