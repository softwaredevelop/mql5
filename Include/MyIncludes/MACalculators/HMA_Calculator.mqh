//+------------------------------------------------------------------+
//|                                                HMA_Calculator.mqh|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#ifndef HMA_CALCULATOR_MQH
#define HMA_CALCULATOR_MQH

#include <MyIncludes\MACalculators\LWMA_Calculator.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CHMACalculator : public CBaseMACalculator
  {
private:
   int               m_half_period;
   int               m_smooth_period;
   CLWMACalculator   m_wma_half;
   CLWMACalculator   m_wma_full;
   CLWMACalculator   m_wma_smooth;

   double            m_half_buffer[];
   double            m_full_buffer[];
   double            m_raw_buffer[];

public:
                     CHMACalculator(void) : m_half_period(1), m_smooth_period(1)
     {
      ArraySetAsSeries(m_half_buffer, false);
      ArraySetAsSeries(m_full_buffer, false);
      ArraySetAsSeries(m_raw_buffer,  false);
     }

   virtual bool      Init(const int period) override
     {
      if(!CBaseMACalculator::Init(period))
         return false;

      m_half_period   = MathMax(1, m_period / 2);
      m_smooth_period = MathMax(1, (int)MathRound(MathSqrt(m_period)));

      if(!m_wma_half.Init(m_half_period))
         return false;
      if(!m_wma_full.Init(m_period))
         return false;
      if(!m_wma_smooth.Init(m_smooth_period))
         return false;

      return true;
     }

   virtual void      Calculate(const int rates_total,
                               const int start_index,
                               const double &price[],
                               const double &volume[],
                               double &output[],
                               const int data_offset = 0) override
     {
      if(ArraySize(m_raw_buffer) != rates_total)
        {
         int old_sz = ArraySize(m_raw_buffer);
         ArrayResize(m_half_buffer, rates_total, 2048);
         ArrayResize(m_full_buffer, rates_total, 2048);
         ArrayResize(m_raw_buffer,  rates_total, 2048);
         ArraySetAsSeries(m_half_buffer, false);
         ArraySetAsSeries(m_full_buffer, false);
         ArraySetAsSeries(m_raw_buffer,  false);

         if(old_sz == 0 || start_index == 0)
           {
            ArrayInitialize(m_half_buffer, EMPTY_VALUE);
            ArrayInitialize(m_full_buffer, EMPTY_VALUE);
            ArrayInitialize(m_raw_buffer,  EMPTY_VALUE);
           }
         else
           {
            for(int k = old_sz; k < rates_total; k++)
              {
               m_half_buffer[k] = EMPTY_VALUE;
               m_full_buffer[k] = EMPTY_VALUE;
               m_raw_buffer[k]  = EMPTY_VALUE;
              }
           }
        }

      int start_full = data_offset + m_period - 1;
      int loop1 = MathMax(start_full, start_index - m_smooth_period - 1);

      m_wma_half.Calculate(rates_total, loop1, price, volume, m_half_buffer, data_offset);
      m_wma_full.Calculate(rates_total, loop1, price, volume, m_full_buffer, data_offset);

      for(int i = loop1; i < rates_total; i++)
        {
         if(m_half_buffer[i] != EMPTY_VALUE && m_full_buffer[i] != EMPTY_VALUE)
            m_raw_buffer[i] = 2.0 * m_half_buffer[i] - m_full_buffer[i];
         else
            m_raw_buffer[i] = EMPTY_VALUE;
        }

      int final_start = start_full + m_smooth_period - 1;
      int loop2 = MathMax(final_start, start_index);

      m_wma_smooth.Calculate(rates_total, loop2, m_raw_buffer, volume, output, start_full);
     }

   virtual int       GetWarmupBars(void) const override
     {
      return m_period + m_smooth_period - 1;
     }
  };

#endif // HMA_CALCULATOR_MQH
//+------------------------------------------------------------------+
