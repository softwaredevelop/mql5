//+------------------------------------------------------------------+
//|                         Bollinger_Bands_Fibonacci_Calculator.mqh |
//|   Calculation engine for Standard and HA Bollinger Bands with    |
//|   Fibonacci Ratio deviations.          Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|      CLASS 1: CBollingerBandsFibonacciCalculator (Standard)      |
//|                                                                  |
//+==================================================================+
class CBollingerBandsFibonacciCalculator
  {
protected:
   int               m_period;
   double            m_fib_ratio1, m_fib_ratio2, m_fib_ratio3;
   ENUM_MA_METHOD    m_ma_method;

   double            m_price[];
   double            m_ma_buffer[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CBollingerBandsFibonacciCalculator(void) {};
   virtual          ~CBollingerBandsFibonacciCalculator(void) {};

   bool              Init(int period, double r1, double r2, double r3, ENUM_MA_METHOD ma_method);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &ma_out[], double &upper1_out[], double &lower1_out[], double &upper2_out[], double &lower2_out[], double &upper3_out[], double &lower3_out[]);
  };

//+------------------------------------------------------------------+
//| CBollingerBandsFibonacciCalculator: Initialization               |
//+------------------------------------------------------------------+
bool CBollingerBandsFibonacciCalculator::Init(int period, double r1, double r2, double r3, ENUM_MA_METHOD ma_method)
  {
   m_period = (period < 1) ? 1 : period;
   m_fib_ratio1 = r1;
   m_fib_ratio2 = r2;
   m_fib_ratio3 = r3;
   m_ma_method = ma_method;
   return true;
  }

//+------------------------------------------------------------------+
//| CBollingerBandsFibonacciCalculator: Main Calculation Method      |
//+------------------------------------------------------------------+
void CBollingerBandsFibonacciCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &ma_out[], double &upper1_out[], double &lower1_out[], double &upper2_out[], double &lower2_out[], double &upper3_out[], double &lower3_out[])
  {
   if(rates_total < m_period)
      return;

   ArrayResize(m_price, rates_total);
   ArrayResize(m_ma_buffer, rates_total);

   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

//--- Step 1: Calculate the centerline (Moving Average)
   int ma_start_pos = m_period - 1;
   for(int i = ma_start_pos; i < rates_total; i++)
     {
      switch(m_ma_method)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == ma_start_pos)
              {
               double sum=0;
               for(int j=0; j<m_period; j++)
                  sum+=m_price[i-j];
               m_ma_buffer[i]=sum/m_period;
              }
            else
              {
               if(m_ma_method==MODE_EMA)
                 {
                  double pr=2.0/(m_period+1.0);
                  m_ma_buffer[i]=m_price[i]*pr + m_ma_buffer[i-1]*(1.0-pr);
                 }
               else
                  m_ma_buffer[i]=(m_ma_buffer[i-1]*(m_period-1)+m_price[i])/m_period;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<m_period; j++)
              {
               int w=m_period-j;
               lwma_sum+=m_price[i-j]*w;
               weight_sum+=w;
              }
            if(weight_sum>0)
               m_ma_buffer[i]=lwma_sum/weight_sum;
           }
         break;
         default:   // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<m_period; j++)
               sum+=m_price[i-j];
            m_ma_buffer[i]=sum/m_period;
           }
         break;
        }
     }

//--- Step 2: Calculate the Standard Deviation and the Bands
   for(int i = ma_start_pos; i < rates_total; i++)
     {
      double std_dev_val = 0, sum_sq = 0;
      for(int j = 0; j < m_period; j++)
         sum_sq += pow(m_price[i-j] - m_ma_buffer[i], 2);
      std_dev_val = sqrt(sum_sq / m_period);

      upper1_out[i] = m_ma_buffer[i] + m_fib_ratio1 * std_dev_val;
      lower1_out[i] = m_ma_buffer[i] - m_fib_ratio1 * std_dev_val;
      upper2_out[i] = m_ma_buffer[i] + m_fib_ratio2 * std_dev_val;
      lower2_out[i] = m_ma_buffer[i] - m_fib_ratio2 * std_dev_val;
      upper3_out[i] = m_ma_buffer[i] + m_fib_ratio3 * std_dev_val;
      lower3_out[i] = m_ma_buffer[i] - m_fib_ratio3 * std_dev_val;
     }

   ArrayCopy(ma_out, m_ma_buffer, 0, 0, rates_total);
  }

//+------------------------------------------------------------------+
//| CBollingerBandsFibonacciCalculator: Prepares the source price.   |
//+------------------------------------------------------------------+
bool CBollingerBandsFibonacciCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   switch(price_type)
     {
      case PRICE_CLOSE:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
      case PRICE_OPEN:
         ArrayCopy(m_price, open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(m_price, high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(m_price, low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (high[i]+low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (high[i]+low[i]+close[i]+close[i])/4.0;
         break;
      default:
         return false;
     }
   return true;
  }

//+==================================================================+
//|                                                                  |
//|      CLASS 2: CBollingerBandsFibonacciCalculator_HA (HA)         |
//|                                                                  |
//+==================================================================+
class CBollingerBandsFibonacciCalculator_HA : public CBollingerBandsFibonacciCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;

protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
  };

//+------------------------------------------------------------------+
//| CBollingerBandsFibonacciCalculator_HA: Prepares the source price.|
//+------------------------------------------------------------------+
bool CBollingerBandsFibonacciCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   switch(price_type)
     {
      case PRICE_CLOSE:
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
      case PRICE_OPEN:
         ArrayCopy(m_price, ha_open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(m_price, ha_high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(m_price, ha_low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (ha_high[i]+ha_low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (ha_high[i]+ha_low[i]+ha_close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (ha_high[i]+ha_low[i]+ha_close[i]+ha_close[i])/4.0;
         break;
      default:
         return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
