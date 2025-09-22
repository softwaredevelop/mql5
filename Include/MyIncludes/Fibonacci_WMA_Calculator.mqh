//+------------------------------------------------------------------+
//|                                     Fibonacci_WMA_Calculator.mqh |
//|      Calculation engine for Standard and Heikin Ashi Fibonacci WMA.|
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CFibonacciWMACalculator (Standard)          |
//|                                                                  |
//+==================================================================+
class CFibonacciWMACalculator
  {
protected:
   int               m_period;
   double            m_weights[];
   double            m_weight_sum;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CFibonacciWMACalculator(void);
   virtual          ~CFibonacciWMACalculator(void) {};

   bool              Init(int period);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &wma_out[]);
  };

//+------------------------------------------------------------------+
//| CFibonacciWMACalculator: Constructor                             |
//+------------------------------------------------------------------+
CFibonacciWMACalculator::CFibonacciWMACalculator(void) : m_period(0), m_weight_sum(0)
  {
  }

//+------------------------------------------------------------------+
//| CFibonacciWMACalculator: Initialization and Weight Generation    |
//+------------------------------------------------------------------+
bool CFibonacciWMACalculator::Init(int period)
  {
   m_period = (period < 2) ? 2 : period;
   if(m_period > 40)
     {
      Print("Fibonacci WMA period is too large, capping at 40 to prevent overflow.");
      m_period = 40;
     }

   ArrayResize(m_weights, m_period);
   m_weight_sum = 0;

//--- Generate Fibonacci numbers
   long fib_numbers[];
   ArrayResize(fib_numbers, m_period);

   long fib1 = 1, fib2 = 1;
   for(int i = 0; i < m_period; i++)
     {
      if(i < 2)
         fib_numbers[i] = 1;
      else
        {
         long fib_next = fib1 + fib2;
         fib_numbers[i] = fib_next;
         fib1 = fib2;
         fib2 = fib_next;
        }
     }

//--- Assign weights in REVERSE order (largest weight for most recent price)
   for(int i = 0; i < m_period; i++)
     {
      m_weights[i] = (double)fib_numbers[m_period - 1 - i];
      m_weight_sum += m_weights[i];
     }

   return (m_weight_sum != 0);
  }

//+------------------------------------------------------------------+
//| CFibonacciWMACalculator: Main Calculation Method                 |
//+------------------------------------------------------------------+
void CFibonacciWMACalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &wma_out[])
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
         //--- Corrected Logic: Most recent price (i-j) gets the highest weight (weights[j])
         weighted_sum += m_price[i - j] * m_weights[j];
        }
      wma_out[i] = weighted_sum / m_weight_sum;
     }
  }

//+------------------------------------------------------------------+
//| CFibonacciWMACalculator: Prepares the source price series.       |
//+------------------------------------------------------------------+
bool CFibonacciWMACalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);
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
//|          CLASS 2: CFibonacciWMACalculator_HA (Heikin Ashi)       |
//|                                                                  |
//+==================================================================+
class CFibonacciWMACalculator_HA : public CFibonacciWMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;

protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
  };

//+------------------------------------------------------------------+
//| CFibonacciWMACalculator_HA: Prepares the source price series.    |
//+------------------------------------------------------------------+
bool CFibonacciWMACalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);

   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayCopy(m_price, ha_close, 0, 0, rates_total);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
