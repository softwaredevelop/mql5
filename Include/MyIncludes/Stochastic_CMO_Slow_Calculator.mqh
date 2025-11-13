//+------------------------------------------------------------------+
//|                                 Stochastic_CMO_Slow_Calculator.mqh |
//|         Engine for Slow Stochastic applied to CMO data.          |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\CMO_Calculator.mqh>

//+==================================================================+
class CStochasticCMOSlowCalculator
  {
protected:
   int               m_cmo_period, m_k_period, m_d_period, m_slowing_period;
   ENUM_MA_METHOD      m_slowing_ma_type, m_d_ma_type;
   CCMOCalculator    *m_cmo_calculator;

   double            Highest(const double &array[], int period, int current_pos);
   double            Lowest(const double &array[], int period, int current_pos);
   void              CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_METHOD method, int start_pos);

public:
                     CStochasticCMOSlowCalculator(void);
   virtual          ~CStochasticCMOSlowCalculator(void);

   bool              Init(int cmo_p, int k_p, int slow_p, ENUM_MA_METHOD slow_ma, int d_p, ENUM_MA_METHOD d_ma);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CStochasticCMOSlowCalculator_HA : public CStochasticCMOSlowCalculator
  {
public:
                     CStochasticCMOSlowCalculator_HA(void);
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStochasticCMOSlowCalculator::CStochasticCMOSlowCalculator(void) { m_cmo_calculator = new CCMOCalculator(); }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStochasticCMOSlowCalculator::~CStochasticCMOSlowCalculator(void) { if(CheckPointer(m_cmo_calculator) != POINTER_INVALID) delete m_cmo_calculator; }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStochasticCMOSlowCalculator_HA::CStochasticCMOSlowCalculator_HA(void)
  {
   if(CheckPointer(m_cmo_calculator) != POINTER_INVALID)
      delete m_cmo_calculator;
   m_cmo_calculator = new CCMOCalculator_HA();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CStochasticCMOSlowCalculator::Init(int cmo_p, int k_p, int slow_p, ENUM_MA_METHOD slow_ma, int d_p, ENUM_MA_METHOD d_ma)
  {
   m_cmo_period      = (cmo_p < 1) ? 1 : cmo_p;
   m_k_period        = (k_p < 1) ? 1 : k_p;
   m_slowing_period  = (slow_p < 1) ? 1 : slow_p;
   m_slowing_ma_type = slow_ma;
   m_d_period        = (d_p < 1) ? 1 : d_p;
   m_d_ma_type       = d_ma;
   if(CheckPointer(m_cmo_calculator) == POINTER_INVALID)
      return false;
   return m_cmo_calculator.Init(m_cmo_period);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStochasticCMOSlowCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &k_buffer[], double &d_buffer[])
  {
   if(rates_total <= m_cmo_period + m_k_period + m_slowing_period + m_d_period)
      return;
   if(CheckPointer(m_cmo_calculator) == POINTER_INVALID)
      return;

   double cmo_buffer[];
   ArrayResize(cmo_buffer, rates_total);
   m_cmo_calculator.Calculate(rates_total, price_type, open, high, low, close, cmo_buffer);

   double raw_k[];
   ArrayResize(raw_k, rates_total);
   int raw_k_start = m_cmo_period + m_k_period - 2;
   for(int i = raw_k_start; i < rates_total; i++)
     {
      double highest_cmo = Highest(cmo_buffer, m_k_period, i);
      double lowest_cmo  = Lowest(cmo_buffer, m_k_period, i);
      double range = highest_cmo - lowest_cmo;
      if(range > 0.00001)
         raw_k[i] = (cmo_buffer[i] - lowest_cmo) / range * 100.0;
      else
         raw_k[i] = (i > 0) ? raw_k[i-1] : 50.0;
     }

   int k_slow_start = m_cmo_period + m_k_period + m_slowing_period - 3;
   CalculateMA(raw_k, k_buffer, m_slowing_period, m_slowing_ma_type, k_slow_start);

   int d_start = k_slow_start + m_d_period - 1;
   CalculateMA(k_buffer, d_buffer, m_d_period, m_d_ma_type, d_start);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CStochasticCMOSlowCalculator::Highest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res < array[index])
         res = array[index];
     }
   return(res);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CStochasticCMOSlowCalculator::Lowest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res > array[index])
         res = array[index];
     }
   return(res);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStochasticCMOSlowCalculator::CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_METHOD method, int start_pos)
  {
   for(int i = start_pos; i < ArraySize(source_array); i++)
     {
      switch(method)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == start_pos)
              {
               double sum=0;
               int count=0;
               for(int j=0; j<period; j++)
                 {
                  if(source_array[i-j] != EMPTY_VALUE)
                    {
                     sum+=source_array[i-j];
                     count++;
                    }
                 }
               if(count > 0)
                  dest_array[i]=sum/count;
              }
            else
              {
               if(method==MODE_EMA)
                 {
                  double pr=2.0/(period+1.0);
                  dest_array[i]=source_array[i]*pr+dest_array[i-1]*(1.0-pr);
                 }
               else
                  dest_array[i]=(dest_array[i-1]*(period-1)+source_array[i])/period;
              }
            break;
         case MODE_LWMA:
           {
            double sum=0, w_sum=0;
            for(int j=0; j<period; j++)
              {
               if(source_array[i-j] == EMPTY_VALUE)
                  continue;
               int w=period-j;
               sum+=source_array[i-j]*w;
               w_sum+=w;
              }
            if(w_sum>0)
               dest_array[i]=sum/w_sum;
           }
         break;
         default: // SMA
           {
            double sum=0;
            int count=0;
            for(int j=0; j<period; j++)
              {
               if(source_array[i-j] != EMPTY_VALUE)
                 {
                  sum+=source_array[i-j];
                  count++;
                 }
              }
            if(count > 0)
               dest_array[i]=sum/count;
           }
         break;
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
