//+------------------------------------------------------------------+
//|                                         PascalWMA_Calculator.mqh |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CPascalWMACalculator (Base Class)           |
//+==================================================================+
class CPascalWMACalculator
  {
protected:
   int               m_period;
   double            m_weights[];
   double            m_weight_sum;

   //--- Persistent Buffer for Incremental Calculation
   double            m_price[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CPascalWMACalculator(void);
   virtual          ~CPascalWMACalculator(void) {};

   bool              Init(int period);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &wma_out[]);
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
// Limit period to avoid double overflow if necessary, but double handles large numbers well (up to 1.7e308).
// Pascal(100) middle term is huge but fits in double.

   ArrayResize(m_weights, m_period);
   m_weight_sum = 0;

// Calculate Binomial Coefficients: C(n, k)
// n = period - 1
// k = 0 to n
// Use iterative formula: C(n, k) = C(n, k-1) * (n - k + 1) / k

   int n = m_period - 1;
   m_weights[0] = 1.0;
   m_weight_sum += m_weights[0];

   for(int k = 1; k <= n; k++)
     {
      // Recursive calculation avoids factorial overflow
      m_weights[k] = m_weights[k-1] * (double)(n - k + 1) / (double)k;
      m_weight_sum += m_weights[k];
     }

   return (m_weight_sum > 0);
  }

//+------------------------------------------------------------------+
//| CPascalWMACalculator: Main Calculation Method                    |
//+------------------------------------------------------------------+
void CPascalWMACalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &wma_out[])
  {
   if(rates_total < m_period)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

// Resize internal buffer
   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- Incremental Loop
   int loop_start = MathMax(m_period - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double weighted_sum = 0;
      // Convolution: Price[i-j] * Weight[j]
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
bool CPascalWMACalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
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
//|             CLASS 2: CPascalWMACalculator_HA (Heikin Ashi)       |
//+==================================================================+
class CPascalWMACalculator_HA : public CPascalWMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];
protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CPascalWMACalculator_HA: Prepares the HA source price.           |
//+------------------------------------------------------------------+
bool CPascalWMACalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_ha_high, m_ha_low, m_ha_close);

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
