//+------------------------------------------------------------------+
//|                                               VWMA_Calculator.mqh|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#ifndef VWMA_CALCULATOR_MQH
#define VWMA_CALCULATOR_MQH

#include <MyIncludes\MACalculators\Base_Calculator.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CVWMACalculator : public CBaseMACalculator
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
         double sum_pv = 0.0;
         double sum_v  = 0.0;

         for(int j = 0; j < m_period; j++)
           {
            double v = volume[i - j];
            sum_pv += price[i - j] * v;
            sum_v  += v;
           }

         output[i] = (sum_v > 0.0) ? (sum_pv / sum_v) : price[i];
        }
     }
  };

#endif // VWMA_CALCULATOR_MQH
//+------------------------------------------------------------------+
