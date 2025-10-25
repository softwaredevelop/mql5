//+------------------------------------------------------------------+
//|                                              MADH_Calculator.mqh |
//|      Calculation engine for the John Ehlers' MADH indicator.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CMADHCalculator (Base Class)                |
//|                                                                  |
//+==================================================================+
class CMADHCalculator
  {
protected:
   int               m_short_len;
   int               m_dom_cycle;
   double            m_price[];

   // Helper function to calculate a Hann-windowed Moving Average
   double            CalcHWMA(int position, int period, const double &price_array[]);

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CMADHCalculator(void) {};
   virtual          ~CMADHCalculator(void) {};

   bool              Init(int short_len, int dom_cycle);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &madh_buffer[]);
  };

//+------------------------------------------------------------------+
bool CMADHCalculator::Init(int short_len, int dom_cycle)
  {
   m_short_len = (short_len < 1) ? 1 : short_len;
   m_dom_cycle = (dom_cycle < 1) ? 1 : dom_cycle;
   return true;
  }

//+------------------------------------------------------------------+
//| Helper function to calculate a Hann-windowed Moving Average      |
//+------------------------------------------------------------------+
double CMADHCalculator::CalcHWMA(int position, int period, const double &price_array[])
  {
   if(position < period - 1)
      return 0.0;

   double sum = 0;
   double coef_sum = 0;

   for(int i = 0; i < period; i++)
     {
      // Ehlers' code uses count from 1 to Length, accessing Close[count-1].
      // This corresponds to i from 0 to period-1, accessing price[position-i].
      double weight = 1.0 - cos(2 * M_PI * (i + 1.0) / (period + 1.0));
      sum += weight * price_array[position - i];
      coef_sum += weight;
     }

   if(coef_sum > 0)
      return sum / coef_sum;

   return 0.0;
  }

//+------------------------------------------------------------------+
void CMADHCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &madh_buffer[])
  {
   int long_len = m_short_len + (int)round(m_dom_cycle / 2.0);
   if(rates_total < long_len)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   for(int i = long_len - 1; i < rates_total; i++)
     {
      // Step 1 & 2: Calculate the two HWMA filters
      double filt1 = CalcHWMA(i, m_short_len, m_price);
      double filt2 = CalcHWMA(i, long_len, m_price);

      // Step 3: Calculate the final MADH value
      if(filt2 != 0)
        {
         madh_buffer[i] = 100.0 * (filt1 - filt2) / filt2;
        }
     }
  }

//+------------------------------------------------------------------+
bool CMADHCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
class CMADHCalculator_HA : public CMADHCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CMADHCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
