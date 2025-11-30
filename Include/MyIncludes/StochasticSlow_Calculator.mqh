//+------------------------------------------------------------------+
//|                                     StochasticSlow_Calculator.mqh|
//|      VERSION 1.20: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|           CLASS 1: CStochasticSlowCalculator (Base Class)        |
//+==================================================================+
class CStochasticSlowCalculator
  {
protected:
   int               m_k_period, m_d_period, m_slowing_period;
   ENUM_MA_METHOD    m_slowing_ma_type, m_d_ma_type;

   //--- Persistent Buffers for Incremental Calculation
   double            m_src_high[], m_src_low[], m_src_close[];
   double            m_raw_k[]; // Stores Fast %K

   double            Highest(int period, int current_pos);
   double            Lowest(int period, int current_pos);

   //--- Updated: Accepts start_index
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CStochasticSlowCalculator(void) {};
   virtual          ~CStochasticSlowCalculator(void) {};

   bool              Init(int k_p, int slow_p, ENUM_MA_METHOD slow_ma, int d_p, ENUM_MA_METHOD d_ma);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochasticSlowCalculator::Init(int k_p, int slow_p, ENUM_MA_METHOD slow_ma, int d_p, ENUM_MA_METHOD d_ma)
  {
   m_k_period        = (k_p < 1) ? 1 : k_p;
   m_slowing_period  = (slow_p < 1) ? 1 : slow_p;
   m_slowing_ma_type = slow_ma;
   m_d_period        = (d_p < 1) ? 1 : d_p;
   m_d_ma_type       = d_ma;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CStochasticSlowCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
   if(rates_total <= m_k_period + m_slowing_period + m_d_period)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_src_high) != rates_total)
     {
      ArrayResize(m_src_high, rates_total);
      ArrayResize(m_src_low, rates_total);
      ArrayResize(m_src_close, rates_total);
      ArrayResize(m_raw_k, rates_total);
     }

//--- 3. Prepare Source Data (Optimized)
   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

//--- 4. Calculate Raw %K (Fast %K)
   int loop_start_k = MathMax(m_k_period - 1, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      double highest_h = Highest(m_k_period, i);
      double lowest_l  = Lowest(m_k_period, i);
      double range = highest_h - lowest_l;

      if(range > 0)
         m_raw_k[i] = (m_src_close[i] - lowest_l) / range * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i-1] : 50.0;
     }

//--- 5. Calculate Slow %K (Main Line)
   int k_slow_start = m_k_period + m_slowing_period - 2;
   int loop_start_slow = MathMax(k_slow_start, start_index);

   for(int i = loop_start_slow; i < rates_total; i++)
     {
      switch(m_slowing_ma_type)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == k_slow_start)
              {
               double sum=0;
               for(int j=0; j<m_slowing_period; j++)
                  sum+=m_raw_k[i-j];
               k_buffer[i]=sum/m_slowing_period;
              }
            else
              {
               if(m_slowing_ma_type==MODE_EMA)
                 {
                  double pr=2.0/(m_slowing_period+1.0);
                  k_buffer[i]=m_raw_k[i]*pr+k_buffer[i-1]*(1.0-pr);
                 }
               else
                  k_buffer[i]=(k_buffer[i-1]*(m_slowing_period-1)+m_raw_k[i])/m_slowing_period;
              }
            break;
         case MODE_LWMA:
           {double sum=0,w_sum=0; for(int j=0; j<m_slowing_period; j++) {int w=m_slowing_period-j; sum+=m_raw_k[i-j]*w; w_sum+=w;} if(w_sum>0) k_buffer[i]=sum/w_sum;}
         break;
         default:
           {double sum=0; for(int j=0; j<m_slowing_period; j++) sum+=m_raw_k[i-j]; k_buffer[i]=sum/m_slowing_period;}
         break;
        }
     }

//--- 6. Calculate %D (Signal Line)
   int d_start = m_k_period + m_slowing_period + m_d_period - 3;
   int loop_start_d = MathMax(d_start, start_index);

   for(int i = loop_start_d; i < rates_total; i++)
     {
      switch(m_d_ma_type)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == d_start)
              {
               double sum=0;
               for(int j=0; j<m_d_period; j++)
                  sum+=k_buffer[i-j];
               d_buffer[i]=sum/m_d_period;
              }
            else
              {
               if(m_d_ma_type==MODE_EMA)
                 {
                  double pr=2.0/(m_d_period+1.0);
                  d_buffer[i]=k_buffer[i]*pr+d_buffer[i-1]*(1.0-pr);
                 }
               else
                  d_buffer[i]=(d_buffer[i-1]*(m_d_period-1)+k_buffer[i])/m_d_period;
              }
            break;
         case MODE_LWMA:
           {double sum=0,w_sum=0; for(int j=0; j<m_d_period; j++) {int w=m_d_period-j; sum+=k_buffer[i-j]*w; w_sum+=w;} if(w_sum>0) d_buffer[i]=sum/w_sum;}
         break;
         default:
           {double sum=0; for(int j=0; j<m_d_period; j++) sum+=k_buffer[i-j]; d_buffer[i]=sum/m_d_period;}
         break;
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Source Data (Standard - Optimized)                       |
//+------------------------------------------------------------------+
bool CStochasticSlowCalculator::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Optimized copy loop
   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i]  = high[i];
      m_src_low[i]   = low[i];
      m_src_close[i] = close[i];
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Highest                                                          |
//+------------------------------------------------------------------+
double CStochasticSlowCalculator::Highest(int period, int current_pos)
  {
   double res = m_src_high[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res < m_src_high[index])
         res = m_src_high[index];
     }
   return(res);
  }

//+------------------------------------------------------------------+
//| Lowest                                                           |
//+------------------------------------------------------------------+
double CStochasticSlowCalculator::Lowest(int period, int current_pos)
  {
   double res = m_src_low[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res > m_src_low[index])
         res = m_src_low[index];
     }
   return(res);
  }

//+==================================================================+
//|         CLASS 2: CStochasticSlowCalculator_HA (Heikin Ashi)      |
//+==================================================================+
class CStochasticSlowCalculator_HA : public CStochasticSlowCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high_temp[], m_ha_low_temp[], m_ha_close_temp[];

protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Source Data (Heikin Ashi - Optimized)                    |
//+------------------------------------------------------------------+
bool CStochasticSlowCalculator_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high_temp, rates_total);
      ArrayResize(m_ha_low_temp, rates_total);
      ArrayResize(m_ha_close_temp, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high_temp, m_ha_low_temp, m_ha_close_temp);

//--- Copy to source buffers (Optimized loop)
   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i]  = m_ha_high_temp[i];
      m_src_low[i]   = m_ha_low_temp[i];
      m_src_close[i] = m_ha_close_temp[i];
     }
   return true;
  }
//+------------------------------------------------------------------+
