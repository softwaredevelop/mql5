//+------------------------------------------------------------------+
//|                                     StochasticSlow_Calculator.mqh|
//| Calculation engine for Standard and Heikin Ashi Slow Stochastic. |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CStochasticSlowCalculator (Base Class)        |
//|                                                                  |
//+==================================================================+
class CStochasticSlowCalculator
  {
protected:
   int               m_k_period, m_d_period, m_slowing_period;
   ENUM_MA_METHOD    m_slowing_ma_type, m_d_ma_type;
   double            m_src_high[], m_src_low[], m_src_close[];

   double            Highest(int period, int current_pos);
   double            Lowest(int period, int current_pos);

   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CStochasticSlowCalculator(void) {};
   virtual          ~CStochasticSlowCalculator(void) {};

   bool              Init(int k_p, int slow_p, ENUM_MA_METHOD slow_ma, int d_p, ENUM_MA_METHOD d_ma);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| CStochasticSlowCalculator: Initialization                        |
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
//| CStochasticSlowCalculator: Main Calculation Method (Shared Logic)|
//+------------------------------------------------------------------+
void CStochasticSlowCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
   if(rates_total <= m_k_period + m_slowing_period + m_d_period)
      return;
   if(!PrepareSourceData(rates_total, open, high, low, close))
      return;

   double raw_k[];
   ArrayResize(raw_k, rates_total);

//--- STEP 1: Calculate Raw %K (Fast %K)
   for(int i = m_k_period - 1; i < rates_total; i++)
     {
      double highest_h = Highest(m_k_period, i);
      double lowest_l  = Lowest(m_k_period, i);
      double range = highest_h - lowest_l;
      if(range > 0)
         raw_k[i] = (m_src_close[i] - lowest_l) / range * 100.0;
      else
         raw_k[i] = (i > 0) ? raw_k[i-1] : 50.0;
     }

//--- STEP 2: Calculate Slow %K (Main Line) by smoothing Raw %K
   int k_slow_start = m_k_period + m_slowing_period - 2;
   for(int i = k_slow_start; i < rates_total; i++)
     {
      switch(m_slowing_ma_type)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == k_slow_start)
              {
               double sum=0;
               for(int j=0; j<m_slowing_period; j++)
                  sum+=raw_k[i-j];
               k_buffer[i]=sum/m_slowing_period;
              }
            else
              {
               if(m_slowing_ma_type==MODE_EMA)
                 {
                  double pr=2.0/(m_slowing_period+1.0);
                  k_buffer[i]=raw_k[i]*pr+k_buffer[i-1]*(1.0-pr);
                 }
               else
                  k_buffer[i]=(k_buffer[i-1]*(m_slowing_period-1)+raw_k[i])/m_slowing_period;
              }
            break;
         case MODE_LWMA:
           {double sum=0,w_sum=0; for(int j=0; j<m_slowing_period; j++) {int w=m_slowing_period-j; sum+=raw_k[i-j]*w; w_sum+=w;} if(w_sum>0) k_buffer[i]=sum/w_sum;}
         break;
         default:
           {double sum=0; for(int j=0; j<m_slowing_period; j++) sum+=raw_k[i-j]; k_buffer[i]=sum/m_slowing_period;}
         break;
        }
     }

//--- STEP 3: Calculate %D (Signal Line) by smoothing Slow %K
   int d_start = m_k_period + m_slowing_period + m_d_period - 3;
   for(int i = d_start; i < rates_total; i++)
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
//| CStochasticSlowCalculator: Prepares the standard source data.    |
//+------------------------------------------------------------------+
bool CStochasticSlowCalculator::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_src_high, rates_total);
   ArrayCopy(m_src_high, high, 0, 0, rates_total);
   ArrayResize(m_src_low, rates_total);
   ArrayCopy(m_src_low, low, 0, 0, rates_total);
   ArrayResize(m_src_close, rates_total);
   ArrayCopy(m_src_close, close, 0, 0, rates_total);
   return true;
  }

//+------------------------------------------------------------------+
//| Finds the highest value in the internal price buffer.            |
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
//| Finds the lowest value in the internal price buffer.             |
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
//|                                                                  |
//|         CLASS 2: CStochasticSlowCalculator_HA (Heikin Ashi)      |
//|                                                                  |
//+==================================================================+
class CStochasticSlowCalculator_HA : public CStochasticSlowCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CStochasticSlowCalculator_HA: Prepares the HA source data.       |
//+------------------------------------------------------------------+
bool CStochasticSlowCalculator_HA::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(m_src_high, rates_total);
   ArrayResize(m_src_low, rates_total);
   ArrayResize(m_src_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, m_src_high, m_src_low, m_src_close);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
