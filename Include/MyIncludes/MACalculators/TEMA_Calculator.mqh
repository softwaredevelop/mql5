//+------------------------------------------------------------------+
//|                                              TEMA_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#ifndef TEMA_CALCULATOR_MQH
#define TEMA_CALCULATOR_MQH

#include <MyIncludes\MACalculators\EMA_Calculator.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CTEMACalculator : public CBaseMACalculator
  {
private:
   CEMACalculator    m_ema_engine;
   double            m_ema1_buffer[];
   double            m_ema2_buffer[];
   double            m_ema3_buffer[];

public:
                     CTEMACalculator(void)
     {
      ArraySetAsSeries(m_ema1_buffer, false);
      ArraySetAsSeries(m_ema2_buffer, false);
      ArraySetAsSeries(m_ema3_buffer, false);
     }

   virtual bool      Init(const int period) override
     {
      if(!CBaseMACalculator::Init(period))
         return false;
      return m_ema_engine.Init(period);
     }

   virtual void      Calculate(const int rates_total,
                               const int start_index,
                               const double &price[],
                               const double &volume[],
                               double &output[],
                               const int data_offset = 0) override
     {
      if(ArraySize(m_ema1_buffer) != rates_total)
        {
         int old_sz = ArraySize(m_ema1_buffer);
         ArrayResize(m_ema1_buffer, rates_total, 2048);
         ArrayResize(m_ema2_buffer, rates_total, 2048);
         ArrayResize(m_ema3_buffer, rates_total, 2048);
         ArraySetAsSeries(m_ema1_buffer, false);
         ArraySetAsSeries(m_ema2_buffer, false);
         ArraySetAsSeries(m_ema3_buffer, false);

         if(old_sz == 0 || start_index == 0)
           {
            ArrayInitialize(m_ema1_buffer, EMPTY_VALUE);
            ArrayInitialize(m_ema2_buffer, EMPTY_VALUE);
            ArrayInitialize(m_ema3_buffer, EMPTY_VALUE);
           }
         else
           {
            for(int k = old_sz; k < rates_total; k++)
              {
               m_ema1_buffer[k] = EMPTY_VALUE;
               m_ema2_buffer[k] = EMPTY_VALUE;
               m_ema3_buffer[k] = EMPTY_VALUE;
              }
           }
        }

      int start_pos1 = data_offset + m_period - 1;
      int loop1      = MathMax(start_pos1, start_index);
      m_ema_engine.Calculate(rates_total, loop1, price, volume, m_ema1_buffer, data_offset);

      int offset2    = start_pos1;
      int loop2      = MathMax(offset2 + m_period - 1, start_index);
      m_ema_engine.Calculate(rates_total, loop2, m_ema1_buffer, volume, m_ema2_buffer, offset2);

      int offset3    = offset2 + m_period - 1;
      int loop3      = MathMax(offset3 + m_period - 1, start_index);
      m_ema_engine.Calculate(rates_total, loop3, m_ema2_buffer, volume, m_ema3_buffer, offset3);

      for(int i = loop3; i < rates_total; i++)
        {
         if(m_ema1_buffer[i] != EMPTY_VALUE && m_ema2_buffer[i] != EMPTY_VALUE && m_ema3_buffer[i] != EMPTY_VALUE)
            output[i] = 3.0 * m_ema1_buffer[i] - 3.0 * m_ema2_buffer[i] + m_ema3_buffer[i];
         else
            output[i] = EMPTY_VALUE;
        }
     }

   virtual int       GetWarmupBars(void) const override { return 3 * m_period - 3; }
  };

#endif // TEMA_CALCULATOR_MQH
//+------------------------------------------------------------------+
