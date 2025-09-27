//+------------------------------------------------------------------+
//|                                        Stochastic_Calculator.mqh |
//|   Calculation engine for Standard and Heikin Ashi Slow Stochastic|
//|                  with selectable MA types for smoothing.         |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CStochasticCalculator (Base Class)            |
//|                                                                  |
//+==================================================================+
class CStochasticCalculator
  {
protected:
   int               m_k_period;
   int               m_slowing_period;
   int               m_d_period;
   ENUM_MA_METHOD    m_slowing_ma_method;
   ENUM_MA_METHOD    m_d_ma_method;

   //--- Internal data arrays
   double            m_high[];
   double            m_low[];
   double            m_close[];

   //--- Internal calculation buffers
   double            m_raw_k[];

   //--- Helper functions
   double            Highest(int period, int current_pos);
   double            Lowest(int period, int current_pos);
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CStochasticCalculator(void) {};
   virtual          ~CStochasticCalculator(void) {};

   bool              Init(int k_p, int slowing_p, int d_p, ENUM_MA_METHOD slowing_ma, ENUM_MA_METHOD d_ma);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &k_out[], double &d_out[]);
  };

//+------------------------------------------------------------------+
//| CStochasticCalculator: Initialization                            |
//+------------------------------------------------------------------+
bool CStochasticCalculator::Init(int k_p, int slowing_p, int d_p, ENUM_MA_METHOD slowing_ma, ENUM_MA_METHOD d_ma)
  {
   m_k_period = (k_p < 1) ? 1 : k_p;
   m_slowing_period = (slowing_p < 1) ? 1 : slowing_p;
   m_d_period = (d_p < 1) ? 1 : d_p;
   m_slowing_ma_method = slowing_ma;
   m_d_ma_method = d_ma;
   return true;
  }

//+------------------------------------------------------------------+
//| CStochasticCalculator: Main Calculation Method                   |
//+------------------------------------------------------------------+
void CStochasticCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                                      double &k_out[], double &d_out[])
  {
   if(rates_total < m_k_period)
      return;

   if(!PreparePriceSeries(rates_total, open, high, low, close))
      return;

   ArrayResize(m_raw_k, rates_total);

//--- Step 1: Calculate Raw %K (Fast %K)
   for(int i = m_k_period - 1; i < rates_total; i++)
     {
      double highest_high = Highest(m_k_period, i);
      double lowest_low   = Lowest(m_k_period, i);
      double range = highest_high - lowest_low;
      if(range > 0)
         m_raw_k[i] = (m_close[i] - lowest_low) / range * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i-1] : 50.0;
     }

//--- Step 2: Calculate Slow %K (Main Line) by smoothing Raw %K
   int k_slow_start_pos = m_k_period + m_slowing_period - 2;
   for(int i = k_slow_start_pos; i < rates_total; i++)
     {
      // Full MA calculation for Slowing
      switch(m_slowing_ma_method)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == k_slow_start_pos)
              {
               double sum=0;
               for(int j=0; j<m_slowing_period; j++)
                  sum+=m_raw_k[i-j];
               k_out[i]=sum/m_slowing_period;
              }
            else
              {
               if(m_slowing_ma_method==MODE_EMA)
                 {
                  double pr=2.0/(m_slowing_period+1.0);
                  k_out[i]=m_raw_k[i]*pr + k_out[i-1]*(1.0-pr);
                 }
               else
                  k_out[i]=(k_out[i-1]*(m_slowing_period-1)+m_raw_k[i])/m_slowing_period;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<m_slowing_period; j++)
              {
               int w=m_slowing_period-j;
               lwma_sum+=m_raw_k[i-j]*w;
               weight_sum+=w;
              }
            if(weight_sum>0)
               k_out[i]=lwma_sum/weight_sum;
           }
         break;
         default:   // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<m_slowing_period; j++)
               sum+=m_raw_k[i-j];
            k_out[i]=sum/m_slowing_period;
           }
         break;
        }
     }

//--- Step 3: Calculate %D (Signal Line) by smoothing Slow %K
   int d_start_pos = m_k_period + m_slowing_period + m_d_period - 3;
   for(int i = d_start_pos; i < rates_total; i++)
     {
      // Full MA calculation for %D
      switch(m_d_ma_method)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == d_start_pos)
              {
               double sum=0;
               for(int j=0; j<m_d_period; j++)
                  sum+=k_out[i-j];
               d_out[i]=sum/m_d_period;
              }
            else
              {
               if(m_d_ma_method==MODE_EMA)
                 {
                  double pr=2.0/(m_d_period+1.0);
                  d_out[i]=k_out[i]*pr + d_out[i-1]*(1.0-pr);
                 }
               else
                  d_out[i]=(d_out[i-1]*(m_d_period-1)+k_out[i])/m_d_period;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<m_d_period; j++)
              {
               int w=m_d_period-j;
               lwma_sum+=k_out[i-j]*w;
               weight_sum+=w;
              }
            if(weight_sum>0)
               d_out[i]=lwma_sum/weight_sum;
           }
         break;
         default:   // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<m_d_period; j++)
               sum+=k_out[i-j];
            d_out[i]=sum/m_d_period;
           }
         break;
        }
     }
  }

//+------------------------------------------------------------------+
//| CStochasticCalculator: Prepares the source price series.         |
//+------------------------------------------------------------------+
bool CStochasticCalculator::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_high, rates_total);
   ArrayResize(m_low, rates_total);
   ArrayResize(m_close, rates_total);
   ArrayCopy(m_high, high);
   ArrayCopy(m_low, low);
   ArrayCopy(m_close, close);
   return true;
  }

//+------------------------------------------------------------------+
//| CStochasticCalculator: Helper for Highest                        |
//+------------------------------------------------------------------+
double CStochasticCalculator::Highest(int period, int current_pos)
  {
   double res = m_high[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res < m_high[index])
         res = m_high[index];
     }
   return(res);
  }

//+------------------------------------------------------------------+
//| CStochasticCalculator: Helper for Lowest                         |
//+------------------------------------------------------------------+
double CStochasticCalculator::Lowest(int period, int current_pos)
  {
   double res = m_low[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res > m_low[index])
         res = m_low[index];
     }
   return(res);
  }

//+==================================================================+
//|                                                                  |
//|           CLASS 2: CStochasticCalculator_HA (Heikin Ashi)        |
//|                                                                  |
//+==================================================================+
class CStochasticCalculator_HA : public CStochasticCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;

protected:
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);
  };

//+------------------------------------------------------------------+
//| CStochasticCalculator_HA: Prepares the source price series.      |
//+------------------------------------------------------------------+
bool CStochasticCalculator_HA::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_high, rates_total);
   ArrayResize(m_low, rates_total);
   ArrayResize(m_close, rates_total);

   double ha_open[];
   ArrayResize(ha_open, rates_total);

   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, m_high, m_low, m_close);

   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
