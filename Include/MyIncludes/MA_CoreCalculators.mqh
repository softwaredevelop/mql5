//+------------------------------------------------------------------+
//|                                          MA_CoreCalculators.mqh  |
//|                 Enterprise Modular Moving Average DSP Engines    |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00"
#property library

#ifndef MA_CORE_CALCULATORS_MQH
#define MA_CORE_CALCULATORS_MQH

//+------------------------------------------------------------------+
//| ABSTRACT BASE CLASS: CBaseMACalculator                           |
//+------------------------------------------------------------------+
class CBaseMACalculator
  {
protected:
   int               m_period;
   double            m_inv_period;

public:
                     CBaseMACalculator(void) : m_period(1), m_inv_period(1.0) {}
   virtual          ~CBaseMACalculator(void) {}

   virtual bool      Init(const int period)
     {
      m_period     = (period < 1) ? 1 : period;
      m_inv_period = 1.0 / (double)m_period;
      return true;
     }

   virtual void      Calculate(const int rates_total,
                               const int start_index,
                               const double &price[],
                               const double &volume[],
                               double &output[],
                               const int data_offset = 0) = 0;

   virtual int       GetWarmupBars(void) const { return m_period - 1; }
  };

//+------------------------------------------------------------------+
//| CLASS: CSMACalculator (Simple Moving Average)                    |
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

//+------------------------------------------------------------------+
//| CLASS: CEMACalculator (Exponential Moving Average)               |
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

//+------------------------------------------------------------------+
//| CLASS: CSMMACalculator (Smoothed Moving Average)                 |
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

//+------------------------------------------------------------------+
//| CLASS: CLWMACalculator (Linear Weighted Moving Average)          |
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

//+------------------------------------------------------------------+
//| CLASS: CTMACalculator (Triangular Moving Average)                |
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

      // Pipelined Lookback Window: Stage 1 must cover all required lookback bars for Stage 2
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

//+------------------------------------------------------------------+
//| CLASS: CDEMACalculator (Double Exponential Moving Average)       |
//+------------------------------------------------------------------+
class CDEMACalculator : public CBaseMACalculator
  {
private:
   CEMACalculator    m_ema_engine;
   double            m_ema1_buffer[];
   double            m_ema2_buffer[];

public:
                     CDEMACalculator(void)
     {
      ArraySetAsSeries(m_ema1_buffer, false);
      ArraySetAsSeries(m_ema2_buffer, false);
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
         ArraySetAsSeries(m_ema1_buffer, false);
         ArraySetAsSeries(m_ema2_buffer, false);

         if(old_sz == 0 || start_index == 0)
           {
            ArrayInitialize(m_ema1_buffer, EMPTY_VALUE);
            ArrayInitialize(m_ema2_buffer, EMPTY_VALUE);
           }
         else
           {
            for(int k = old_sz; k < rates_total; k++)
              {
               m_ema1_buffer[k] = EMPTY_VALUE;
               m_ema2_buffer[k] = EMPTY_VALUE;
              }
           }
        }

      int start_pos1 = data_offset + m_period - 1;
      int loop1      = MathMax(start_pos1, start_index);
      m_ema_engine.Calculate(rates_total, loop1, price, volume, m_ema1_buffer, data_offset);

      int offset2    = start_pos1;
      int loop2      = MathMax(offset2 + m_period - 1, start_index);
      m_ema_engine.Calculate(rates_total, loop2, m_ema1_buffer, volume, m_ema2_buffer, offset2);

      for(int i = loop2; i < rates_total; i++)
        {
         if(m_ema1_buffer[i] != EMPTY_VALUE && m_ema2_buffer[i] != EMPTY_VALUE)
            output[i] = 2.0 * m_ema1_buffer[i] - m_ema2_buffer[i];
         else
            output[i] = EMPTY_VALUE;
        }
     }

   virtual int       GetWarmupBars(void) const override { return 2 * m_period - 2; }
  };

//+------------------------------------------------------------------+
//| CLASS: CTEMACalculator (Triple Exponential Moving Average)       |
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

//+------------------------------------------------------------------+
//| CLASS: CVWMACalculator (Volume Weighted Moving Average)          |
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

#endif // MA_CORE_CALCULATORS_MQH
//+------------------------------------------------------------------+