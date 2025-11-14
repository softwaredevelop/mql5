//+------------------------------------------------------------------+
//|                                     RSI_Adaptive_Calculator.mqh  |
//|      Engine for a variable-length RSI (Dynamic Momentum Index).  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
class CAdaptiveRSICalculator
  {
protected:
   int               m_pivotal_period, m_vola_short, m_vola_long;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CAdaptiveRSICalculator(void) {};
   virtual          ~CAdaptiveRSICalculator(void) {};

   bool              Init(int pivotal_p, int vola_s, int vola_l);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &rsi_buffer[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CAdaptiveRSICalculator_HA : public CAdaptiveRSICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CAdaptiveRSICalculator::Init(int pivotal_p, int vola_s, int vola_l)
  {
   m_pivotal_period = (pivotal_p < 2) ? 2 : pivotal_p;
   m_vola_short = (vola_s < 1) ? 1 : vola_s;
   m_vola_long = (vola_l <= m_vola_short) ? m_vola_short + 1 : vola_l;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CAdaptiveRSICalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                                       double &rsi_buffer[])
  {
   if(rates_total <= m_vola_long + m_pivotal_period)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   double vola_sum[], vola_avg[], nsp_buffer[];
   ArrayResize(vola_sum, rates_total);
   ArrayResize(vola_avg, rates_total);
   ArrayResize(nsp_buffer, rates_total);

//--- Step 1: Calculate Volatility Ratio and Adaptive Period (NSP)
   for(int i = m_vola_short; i < rates_total; i++)
     {
      for(int j = 0; j < m_vola_short; j++)
         vola_sum[i] += MathAbs(m_price[i-j] - m_price[i-j-1]);
     }
   for(int i = m_vola_short + m_vola_long - 1; i < rates_total; i++)
     {
      double sum_of_sums = 0;
      for(int j = 0; j < m_vola_long; j++)
         sum_of_sums += vola_sum[i-j];
      vola_avg[i] = sum_of_sums / m_vola_long;

      double vola_ratio = (vola_avg[i] > 0.000001) ? vola_sum[i] / vola_avg[i] : 1.0;

      int period = (int)round(m_pivotal_period / vola_ratio);
      nsp_buffer[i] = fmax(2, fmin(m_pivotal_period * 2, period)); // Clamp period to a reasonable range
     }

//--- Step 2: Calculate Simple RSI using the adaptive period
   for(int i = m_vola_long + m_pivotal_period; i < rates_total; i++)
     {
      int current_nsp = (int)nsp_buffer[i];
      if(i < current_nsp)
         continue;

      double sum_pos = 0, sum_neg = 0;
      for(int j = 0; j < current_nsp; j++)
        {
         double diff = m_price[i-j] - m_price[i-j-1];
         if(diff > 0)
            sum_pos += diff;
         else
            sum_neg -= diff;
        }

      if(sum_pos + sum_neg > 0.000001)
         rsi_buffer[i] = 100.0 * sum_pos / (sum_pos + sum_neg);
      else
         rsi_buffer[i] = 50.0;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CAdaptiveRSICalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
      if(ArrayResize(m_price, rates_total) != rates_total)
         return false;

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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CAdaptiveRSICalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   if(ArraySize(m_price) != rates_total)
      if(ArrayResize(m_price, rates_total) != rates_total)
         return false;

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
