//+------------------------------------------------------------------+
//|                                      StochRSI_Slow_Calculator.mqh|
//|  Calculation engine for Standard and Heikin Ashi Slow StochRSI.  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\RSI_Pro_Calculator.mqh> // Re-use the RSI Pro engine

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CStochRSI_Slow_Calculator (Base Class)        |
//|                                                                  |
//+==================================================================+
class CStochRSI_Slow_Calculator
  {
protected:
   int               m_rsi_period, m_k_period, m_d_period, m_slowing_period;
   ENUM_MA_METHOD    m_slowing_ma_type, m_d_ma_type;
   CRSIProCalculator *m_rsi_calculator;

   double            Highest(const double &array[], int period, int current_pos);
   double            Lowest(const double &array[], int period, int current_pos);

public:
                     CStochRSI_Slow_Calculator(void);
   virtual          ~CStochRSI_Slow_Calculator(void);

   bool              Init(int rsi_p, int k_p, int slow_p, ENUM_MA_METHOD slow_ma, int d_p, ENUM_MA_METHOD d_ma);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| CStochRSI_Slow_Calculator: Constructor                           |
//+------------------------------------------------------------------+
CStochRSI_Slow_Calculator::CStochRSI_Slow_Calculator(void)
  {
   m_rsi_calculator = new CRSIProCalculator();
  }

//+------------------------------------------------------------------+
//| CStochRSI_Slow_Calculator: Destructor                            |
//+------------------------------------------------------------------+
CStochRSI_Slow_Calculator::~CStochRSI_Slow_Calculator(void)
  {
   if(CheckPointer(m_rsi_calculator) != POINTER_INVALID)
      delete m_rsi_calculator;
  }

//+------------------------------------------------------------------+
//| CStochRSI_Slow_Calculator: Initialization                        |
//+------------------------------------------------------------------+
bool CStochRSI_Slow_Calculator::Init(int rsi_p, int k_p, int slow_p, ENUM_MA_METHOD slow_ma, int d_p, ENUM_MA_METHOD d_ma)
  {
   m_rsi_period      = (rsi_p < 1) ? 1 : rsi_p;
   m_k_period        = (k_p < 1) ? 1 : k_p;
   m_slowing_period  = (slow_p < 1) ? 1 : slow_p;
   m_slowing_ma_type = slow_ma;
   m_d_period        = (d_p < 1) ? 1 : d_p;
   m_d_ma_type       = d_ma;

   if(CheckPointer(m_rsi_calculator) == POINTER_INVALID)
      return false;
   return m_rsi_calculator.Init(m_rsi_period, 1, MODE_SMA, 2.0); // Other params are not used
  }

//+------------------------------------------------------------------+
//| CStochRSI_Slow_Calculator: Main Calculation Method               |
//+------------------------------------------------------------------+
void CStochRSI_Slow_Calculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &k_buffer[], double &d_buffer[])
  {
   if(rates_total <= m_rsi_period + m_k_period + m_slowing_period + m_d_period)
      return;
   if(CheckPointer(m_rsi_calculator) == POINTER_INVALID)
      return;

   double rsi_buffer[], dummy1[], dummy2[], dummy3[];
   ArrayResize(rsi_buffer, rates_total);
   m_rsi_calculator.Calculate(rates_total, price_type, open, high, low, close, rsi_buffer, dummy1, dummy2, dummy3);

   double raw_k[];
   ArrayResize(raw_k, rates_total);
   int raw_k_start = m_rsi_period + m_k_period - 2;
   for(int i = raw_k_start; i < rates_total; i++)
     {
      double highest_rsi = Highest(rsi_buffer, m_k_period, i);
      double lowest_rsi  = Lowest(rsi_buffer, m_k_period, i);
      double range = highest_rsi - lowest_rsi;
      if(range > 0.00001)
         raw_k[i] = (rsi_buffer[i] - lowest_rsi) / range * 100.0;
      else
         raw_k[i] = (i > 0) ? raw_k[i-1] : 50.0;
     }

   int k_slow_start = m_rsi_period + m_k_period + m_slowing_period - 3;
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

   int d_start = k_slow_start + m_d_period - 1;
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
//| Finds the highest value in a given period of an array.           |
//+------------------------------------------------------------------+
double CStochRSI_Slow_Calculator::Highest(const double &array[], int period, int current_pos)
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
//| Finds the lowest value in a given period of an array.            |
//+------------------------------------------------------------------+
double CStochRSI_Slow_Calculator::Lowest(const double &array[], int period, int current_pos)
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

//+==================================================================+
//|                                                                  |
//|         CLASS 2: CStochRSI_Slow_Calculator_HA (Heikin Ashi)      |
//|                                                                  |
//+==================================================================+
class CStochRSI_Slow_Calculator_HA : public CStochRSI_Slow_Calculator
  {
public:
                     CStochRSI_Slow_Calculator_HA(void);
  };

//+------------------------------------------------------------------+
//| CStochRSI_Slow_Calculator_HA: Constructor                        |
//+------------------------------------------------------------------+
CStochRSI_Slow_Calculator_HA::CStochRSI_Slow_Calculator_HA(void)
  {
   if(CheckPointer(m_rsi_calculator) != POINTER_INVALID)
      delete m_rsi_calculator;
   m_rsi_calculator = new CRSIProCalculator_HA();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
