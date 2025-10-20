//+------------------------------------------------------------------+
//|                                              RSIH_Calculator.mqh |
//|    Calculation engine for Ehlers' RSI with Hann Windowing.       |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CRSIHCalculator (Base Class)                |
//|                                                                  |
//+==================================================================+
class CRSIHCalculator
  {
protected:
   int               m_period;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CRSIHCalculator(void) {};
   virtual          ~CRSIHCalculator(void) {};

   bool              Init(int period);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &rsih_buffer[]);
  };

//+------------------------------------------------------------------+
bool CRSIHCalculator::Init(int period)
  {
   m_period = (period < 2) ? 2 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| RESTORED: Original, definition-true FIR-based calculation        |
//| based on Ehlers' EasyLanguage code.                              |
//+------------------------------------------------------------------+
void CRSIHCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &rsih_buffer[])
  {
   if(rates_total < m_period + 1)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

// Full recalculation for stability
   for(int i = m_period; i < rates_total; i++)
     {
      double cu = 0.0;
      double cd = 0.0;

      // Inner loop to calculate Hann-windowed CU and CD over the lookback period
      for(int j = 1; j <= m_period; j++)
        {
         // Ehlers' EasyLanguage: Close[count-1] - Close[count]
         // In our chronological array (non-timeseries), this corresponds to:
         // count=1 -> m_price[i-1] - m_price[i] (most recent)
         // count=m_period -> m_price[i-m_period] - m_price[i-m_period-1] (oldest)
         // Let's use a consistent diff: m_price[i-j+1] - m_price[i-j]
         double diff = m_price[i - j + 1] - m_price[i - j];

         // Hann Windowing Weight, where j corresponds to Ehlers' 'count'
         double weight = 1.0 - cos(2 * M_PI * j / (m_period + 1.0));

         if(diff > 0)
            cu += diff * weight;
         else
            cd += -diff * weight;
        }

      if(cu + cd > 0)
         rsih_buffer[i] = (cu - cd) / (cu + cd);
      else
         rsih_buffer[i] = (i > 0) ? rsih_buffer[i-1] : 0.0; // Fallback to previous or 0
     }
  }

//+------------------------------------------------------------------+
bool CRSIHCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
class CRSIHCalculator_HA : public CRSIHCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CRSIHCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
