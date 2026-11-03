//+------------------------------------------------------------------+
//|                                               TMA_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#ifndef TMA_CALCULATOR_MQH
#define TMA_CALCULATOR_MQH

#include <MyIncludes\MACalculators\Base_Calculator.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CTMACalculator : public CBaseMACalculator
  {
private:
   int               m_period1;
   int               m_period2;
   double            m_inv_p1;
   double            m_inv_p2;
   double            m_stage1_buffer[];

public:
                     CTMACalculator(void) : m_period1(1), m_period2(1), m_inv_p1(1.0), m_inv_p2(1.0)
     {
      ArraySetAsSeries(m_stage1_buffer, false);
     }

   virtual bool      Init(const int period) override
     {
      if(!CBaseMACalculator::Init(period))
         return false;

      m_period1 = (int)ceil((m_period + 1.0) * 0.5);
      m_period2 = m_period - m_period1 + 1;
      m_inv_p1  = 1.0 / (double)m_period1;
      m_inv_p2  = 1.0 / (double)m_period2;
      return true;
     }

   virtual void      Calculate(const int rates_total,
                               const int start_index,
                               const double &price[],
                               const double &volume[],
                               double &output[],
                               const int data_offset = 0) override
     {
      if(ArraySize(m_stage1_buffer) != rates_total)
        {
         int old_size = ArraySize(m_stage1_buffer);
         ArrayResize(m_stage1_buffer, rates_total, 2048);
         ArraySetAsSeries(m_stage1_buffer, false);
         if(old_size == 0 || start_index == 0)
            ArrayInitialize(m_stage1_buffer, EMPTY_VALUE);
         else
            for(int k = old_size; k < rates_total; k++)
               m_stage1_buffer[k] = EMPTY_VALUE;
        }

      int start_pos1 = data_offset + m_period1 - 1;
      int start_pos2 = start_pos1 + m_period2 - 1;

      int loop_start_stage1 = MathMax(start_pos1, start_index - m_period2 - 1);

      for(int i = loop_start_stage1; i < rates_total; i++)
        {
         double sum = 0.0;
         for(int j = 0; j < m_period1; j++)
            sum += price[i - j];
         m_stage1_buffer[i] = sum * m_inv_p1;
        }

      int loop_start_stage2 = MathMax(start_pos2, start_index);

      for(int i = loop_start_stage2; i < rates_total; i++)
        {
         double sum = 0.0;
         for(int j = 0; j < m_period2; j++)
            sum += m_stage1_buffer[i - j];
         output[i] = sum * m_inv_p2;
        }
     }

   virtual int       GetWarmupBars(void) const override { return m_period - 1; }
  };

#endif // TMA_CALCULATOR_MQH
//+------------------------------------------------------------------+
