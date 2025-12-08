//+------------------------------------------------------------------+
//|                         Bollinger_Bands_Fibonacci_Calculator.mqh |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|      CLASS 1: CBollingerBandsFibonacciCalculator (Standard)      |
//+==================================================================+
class CBollingerBandsFibonacciCalculator
  {
protected:
   int               m_period;
   double            m_fib_ratio1, m_fib_ratio2, m_fib_ratio3;
   ENUM_MA_METHOD    m_ma_method;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];
   double            m_ma_buffer[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CBollingerBandsFibonacciCalculator(void) {};
   virtual          ~CBollingerBandsFibonacciCalculator(void) {};

   bool              Init(int period, double r1, double r2, double r3, ENUM_MA_METHOD ma_method);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &ma_out[], double &upper1_out[], double &lower1_out[], double &upper2_out[], double &lower2_out[], double &upper3_out[], double &lower3_out[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
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
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CBollingerBandsFibonacciCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &ma_out[], double &upper1_out[], double &lower1_out[], double &upper2_out[], double &lower2_out[], double &upper3_out[], double &lower3_out[])
  {
   if(rates_total < m_period)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_ma_buffer, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Calculate Centerline (MA) - Incremental
   int ma_start_pos = m_period - 1;
   int loop_start = MathMax(ma_start_pos, start_index);

   for(int i = loop_start; i < rates_total; i++)
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

//--- 5. Calculate Bands (Incremental)
   for(int i = loop_start; i < rates_total; i++)
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
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CBollingerBandsFibonacciCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Optimized copy loop
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = high[i];
            break;
         case PRICE_LOW:
            m_price[i] = low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (high[i]+low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|      CLASS 2: CBollingerBandsFibonacciCalculator_HA (HA)         |
//+==================================================================+
class CBollingerBandsFibonacciCalculator_HA : public CBollingerBandsFibonacciCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CBollingerBandsFibonacciCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

//--- Copy to m_price (Optimized loop)
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = m_ha_close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = m_ha_open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = m_ha_high[i];
            break;
         case PRICE_LOW:
            m_price[i] = m_ha_low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (m_ha_high[i]+m_ha_low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+m_ha_close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+2*m_ha_close[i])/4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
