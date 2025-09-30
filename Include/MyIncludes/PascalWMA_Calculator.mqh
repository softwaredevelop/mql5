//+------------------------------------------------------------------+
//|                                         PascalWMA_Calculator.mqh |
//|      Calculation engine for Standard and Heikin Ashi Pascal WMA. |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CPascalWMACalculator (Base Class)           |
//|                                                                  |
//+==================================================================+
class CPascalWMACalculator
  {
protected:
   int               m_period;
   double            m_weights[];
   double            m_weight_sum;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CPascalWMACalculator(void);
   virtual          ~CPascalWMACalculator(void) {};

   bool              Init(int period);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &wma_out[]);
  };

//+------------------------------------------------------------------+
//| CPascalWMACalculator: Constructor                                |
//+------------------------------------------------------------------+
CPascalWMACalculator::CPascalWMACalculator(void) : m_period(0), m_weight_sum(0)
  {
  }

//+------------------------------------------------------------------+
//| CPascalWMACalculator: Initialization and Weight Generation       |
//+------------------------------------------------------------------+
bool CPascalWMACalculator::Init(int period)
  {
   m_period = (period < 2) ? 2 : period;
   ArrayResize(m_weights, m_period);
   m_weight_sum = 0;

   for(int i = 0; i < m_period; i++)
     {
      long n = m_period - 1;
      long k = i;
      if(k > n / 2)
         k = n - k;
      long res = 1;
      for(long j = 1; j <= k; j++)
        {
         if(j == 0)
            continue;
         res = res * (n - j + 1) / j;
        }
      m_weights[i] = (double)res;
      m_weight_sum += m_weights[i];
     }
   return (m_weight_sum > 0);
  }

//+------------------------------------------------------------------+
//| CPascalWMACalculator: Main Calculation Method                    |
//+------------------------------------------------------------------+
void CPascalWMACalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &wma_out[])
  {
   if(rates_total < m_period)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   for(int i = m_period - 1; i < rates_total; i++)
     {
      double weighted_sum = 0;
      for(int j = 0; j < m_period; j++)
        {
         weighted_sum += m_price[i - j] * m_weights[j];
        }
      wma_out[i] = weighted_sum / m_weight_sum;
     }
  }

//+------------------------------------------------------------------+
//| CPascalWMACalculator: Prepares the standard source price.        |
//+------------------------------------------------------------------+
bool CPascalWMACalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);
   switch(price_type)
     {
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
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
     }
   return true;
  }

//+==================================================================+
//|                                                                  |
//|           CLASS 2: CPascalWMACalculator_HA (Heikin Ashi)         |
//|                                                                  |
//+==================================================================+
class CPascalWMACalculator_HA : public CPascalWMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CPascalWMACalculator_HA: Prepares the HA source price.           |
//+------------------------------------------------------------------+
bool CPascalWMACalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_price, rates_total);
   switch(price_type)
     {
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
            m_price[i] = (ha_high[i]+ha_low[i]+2*ha_close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
