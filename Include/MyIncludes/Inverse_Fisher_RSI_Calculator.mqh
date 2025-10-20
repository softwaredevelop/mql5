//+------------------------------------------------------------------+
//|                               Inverse_Fisher_RSI_Calculator.mqh  |
//|      Calculation engine for the Inverse Fisher Transform of RSI. |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|         CLASS 1: CInverseFisherRSICalculator (Base)              |
//|                                                                  |
//+==================================================================+
class CInverseFisherRSICalculator
  {
protected:
   int               m_rsi_period;
   int               m_wma_period;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CInverseFisherRSICalculator(void) {};
   virtual          ~CInverseFisherRSICalculator(void) {};

   bool              Init(int rsi_period, int wma_period);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &ifish_buffer[]);
  };

//+------------------------------------------------------------------+
bool CInverseFisherRSICalculator::Init(int rsi_period, int wma_period)
  {
   m_rsi_period = (rsi_period < 2) ? 2 : rsi_period;
   m_wma_period = (wma_period < 1) ? 1 : wma_period;
   return true;
  }

//+------------------------------------------------------------------+
void CInverseFisherRSICalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &ifish_buffer[])
  {
   if(rates_total < m_rsi_period + m_wma_period)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   double rsi_buffer[], value1[], value2[];
   ArrayResize(rsi_buffer, rates_total);
   ArrayResize(value1, rates_total);
   ArrayResize(value2, rates_total);

// Step 1: Calculate RSI (Wilder's method)
   double sum_pos = 0, sum_neg = 0;
   for(int i = 1; i < rates_total; i++)
     {
      double diff = m_price[i] - m_price[i-1];
      sum_pos = (sum_pos * (m_rsi_period - 1) + (diff > 0 ? diff : 0)) / m_rsi_period;
      sum_neg = (sum_neg * (m_rsi_period - 1) + (diff < 0 ? -diff : 0)) / m_rsi_period;
      if(i >= m_rsi_period)
        {
         if(sum_neg > 0)
            rsi_buffer[i] = 100.0 - (100.0 / (1.0 + (sum_pos / sum_neg)));
         else
            rsi_buffer[i] = 100.0;
        }
     }

// Step 2 & 3: Scale and Smooth with WMA
   for(int i = m_rsi_period - 1; i < rates_total; i++)
     {
      // Scale RSI from 0..100 to -5..+5
      value1[i] = 0.1 * (rsi_buffer[i] - 50.0);

      // Smooth with WMA
      if(i >= m_rsi_period - 1 + m_wma_period - 1)
        {
         double wma_sum = 0;
         double weight_sum = 0;
         for(int j = 0; j < m_wma_period; j++)
           {
            int weight = m_wma_period - j;
            wma_sum += value1[i-j] * weight;
            weight_sum += weight;
           }
         if(weight_sum > 0)
            value2[i] = wma_sum / weight_sum;
        }
     }

// Step 4: Apply Inverse Fisher Transform
   for(int i = m_rsi_period - 1 + m_wma_period - 1; i < rates_total; i++)
     {
      ifish_buffer[i] = (exp(2.0 * value2[i]) - 1.0) / (exp(2.0 * value2[i]) + 1.0);
     }
  }

//+------------------------------------------------------------------+
bool CInverseFisherRSICalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);
   ArrayCopy(m_price, close, 0, 0, rates_total); // Ehlers' example uses Close for RSI
   return true;
  }

//+==================================================================+
class CInverseFisherRSICalculator_HA : public CInverseFisherRSICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CInverseFisherRSICalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_price, rates_total);
   ArrayCopy(m_price, ha_close, 0, 0, rates_total);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
