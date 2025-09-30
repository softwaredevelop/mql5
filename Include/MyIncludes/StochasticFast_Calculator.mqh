//+------------------------------------------------------------------+
//|                                     StochasticFast_Calculator.mqh|
//| Calculation engine for Standard and Heikin Ashi Fast Stochastic. |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CStochasticFastCalculator (Base Class)        |
//|                                                                  |
//+==================================================================+
class CStochasticFastCalculator
  {
protected:
   int               m_k_period, m_d_period;
   ENUM_MA_METHOD    m_d_ma_type;
   double            m_src_high[], m_src_low[], m_src_close[];

   double            Highest(int period, int current_pos);
   double            Lowest(int period, int current_pos);

   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CStochasticFastCalculator(void) {};
   virtual          ~CStochasticFastCalculator(void) {};

   bool              Init(int k_p, int d_p, ENUM_MA_METHOD d_ma);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| CStochasticFastCalculator: Initialization                        |
//+------------------------------------------------------------------+
bool CStochasticFastCalculator::Init(int k_p, int d_p, ENUM_MA_METHOD d_ma)
  {
   m_k_period  = (k_p < 1) ? 1 : k_p;
   m_d_period  = (d_p < 1) ? 1 : d_p;
   m_d_ma_type = d_ma;
   return true;
  }

//+------------------------------------------------------------------+
//| CStochasticFastCalculator: Main Calculation Method (Shared Logic)|
//+------------------------------------------------------------------+
void CStochasticFastCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
   if(rates_total <= m_k_period + m_d_period)
      return;
   if(!PrepareSourceData(rates_total, open, high, low, close))
      return;

//--- STEP 1: Calculate %K (Fast %K)
   for(int i = m_k_period - 1; i < rates_total; i++)
     {
      double highest_h = Highest(m_k_period, i);
      double lowest_l  = Lowest(m_k_period, i);
      double range = highest_h - lowest_l;
      if(range > 0)
         k_buffer[i] = (m_src_close[i] - lowest_l) / range * 100.0;
      else
         k_buffer[i] = (i > 0) ? k_buffer[i-1] : 50.0;
     }

//--- STEP 2: Calculate %D (Signal Line) by smoothing %K
   int d_start = m_k_period + m_d_period - 2;
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
//| CStochasticFastCalculator: Prepares the standard source data.    |
//+------------------------------------------------------------------+
bool CStochasticFastCalculator::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
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
double CStochasticFastCalculator::Highest(int period, int current_pos)
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
double CStochasticFastCalculator::Lowest(int period, int current_pos)
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
//|         CLASS 2: CStochasticFastCalculator_HA (Heikin Ashi)      |
//|                                                                  |
//+==================================================================+
class CStochasticFastCalculator_HA : public CStochasticFastCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CStochasticFastCalculator_HA: Prepares the HA source data.       |
//+------------------------------------------------------------------+
bool CStochasticFastCalculator_HA::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
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
