//+------------------------------------------------------------------+
//|                                      StochRSI_Fast_Calculator.mqh|
//|  VERSION 1.20: Optimized for incremental calculation.            |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\RSI_Pro_Calculator.mqh>

//+==================================================================+
//|           CLASS 1: CStochRSI_Fast_Calculator (Base Class)        |
//+==================================================================+
class CStochRSI_Fast_Calculator
  {
protected:
   int               m_rsi_period, m_k_period, m_d_period;
   ENUM_MA_METHOD    m_d_ma_type;
   CRSIProCalculator *m_rsi_calculator;

   //--- Persistent Buffers for Incremental Calculation
   double            m_rsi_buffer[];

   double            Highest(const double &array[], int period, int current_pos);
   double            Lowest(const double &array[], int period, int current_pos);

public:
                     CStochRSI_Fast_Calculator(void);
   virtual          ~CStochRSI_Fast_Calculator(void);

   bool              Init(int rsi_p, int k_p, int d_p, ENUM_MA_METHOD d_ma);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStochRSI_Fast_Calculator::CStochRSI_Fast_Calculator(void)
  {
   m_rsi_calculator = new CRSIProCalculator();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStochRSI_Fast_Calculator::~CStochRSI_Fast_Calculator(void)
  {
   if(CheckPointer(m_rsi_calculator) != POINTER_INVALID)
      delete m_rsi_calculator;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochRSI_Fast_Calculator::Init(int rsi_p, int k_p, int d_p, ENUM_MA_METHOD d_ma)
  {
   m_rsi_period = (rsi_p < 1) ? 1 : rsi_p;
   m_k_period   = (k_p < 1) ? 1 : k_p;
   m_d_period   = (d_p < 1) ? 1 : d_p;
   m_d_ma_type  = d_ma;

   if(CheckPointer(m_rsi_calculator) == POINTER_INVALID)
      return false;
   return m_rsi_calculator.Init(m_rsi_period, 1, MODE_SMA, 2.0); // Other params are not used
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CStochRSI_Fast_Calculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &k_buffer[], double &d_buffer[])
  {
   if(rates_total <= m_rsi_period + m_k_period + m_d_period)
      return;
   if(CheckPointer(m_rsi_calculator) == POINTER_INVALID)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Internal Buffers
   if(ArraySize(m_rsi_buffer) != rates_total)
      ArrayResize(m_rsi_buffer, rates_total);

//--- 3. Calculate RSI (Incremental)
   double dummy1[], dummy2[], dummy3[];
   m_rsi_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                              m_rsi_buffer, dummy1, dummy2, dummy3);

//--- 4. Calculate %K (Fast %K)
   int k_start = m_rsi_period + m_k_period - 2;
   int loop_start_k = MathMax(k_start, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      double highest_rsi = Highest(m_rsi_buffer, m_k_period, i);
      double lowest_rsi  = Lowest(m_rsi_buffer, m_k_period, i);
      double range = highest_rsi - lowest_rsi;

      if(range > 0.00001)
         k_buffer[i] = (m_rsi_buffer[i] - lowest_rsi) / range * 100.0;
      else
         k_buffer[i] = (i > 0) ? k_buffer[i-1] : 50.0;
     }

//--- 5. Calculate %D (Signal Line) by smoothing %K
   int d_start = k_start + m_d_period - 1;
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
//| Highest                                                          |
//+------------------------------------------------------------------+
double CStochRSI_Fast_Calculator::Highest(const double &array[], int period, int current_pos)
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
//| Lowest                                                           |
//+------------------------------------------------------------------+
double CStochRSI_Fast_Calculator::Lowest(const double &array[], int period, int current_pos)
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
//|         CLASS 2: CStochRSI_Fast_Calculator_HA (Heikin Ashi)      |
//+==================================================================+
class CStochRSI_Fast_Calculator_HA : public CStochRSI_Fast_Calculator
  {
public:
                     CStochRSI_Fast_Calculator_HA(void);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStochRSI_Fast_Calculator_HA::CStochRSI_Fast_Calculator_HA(void)
  {
   if(CheckPointer(m_rsi_calculator) != POINTER_INVALID)
      delete m_rsi_calculator;
   m_rsi_calculator = new CRSIProCalculator_HA();
  }
//+------------------------------------------------------------------+
