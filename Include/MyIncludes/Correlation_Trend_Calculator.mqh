//+------------------------------------------------------------------+
//|                               Correlation_Trend_Calculator.mqh   |
//|      Calculation engine for the John Ehlers' Correlation Trend   |
//|      Indicator.                                                  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
class CCorrelationTrendCalculator
  {
protected:
   int               m_period;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CCorrelationTrendCalculator(void) {};
   virtual          ~CCorrelationTrendCalculator(void) {};

   bool              Init(int period);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &corr_buffer[]);
  };

//+------------------------------------------------------------------+
bool CCorrelationTrendCalculator::Init(int period)
  {
   m_period = (period < 2) ? 2 : period;
   return true;
  }

//+------------------------------------------------------------------+
void CCorrelationTrendCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &corr_buffer[])
  {
   if(rates_total < m_period)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   for(int i = m_period - 1; i < rates_total; i++)
     {
      double sx=0, sy=0, sxx=0, syy=0, sxy=0;

      for(int j = 0; j < m_period; j++)
        {
         // x is the price, from newest (j=0) to oldest (j=m_period-1)
         double x = m_price[i - j];
         // y is a time index with a positive slope
         double y = j + 1;

         sx += x;
         sy += y;
         sxx += x * x;
         syy += y * y;
         sxy += x * y;
        }

      double numerator = m_period * sxy - sx * sy;
      double den_term1 = m_period * sxx - sx * sx;
      double den_term2 = m_period * syy - sy * sy;

      if(den_term1 > 0 && den_term2 > 0)
        {
         double denominator = sqrt(den_term1 * den_term2);
         if(denominator != 0)
           {
            // CORRECTED: The correlation of a rising price with a rising time index is positive.
            // Ehlers wants a positive correlation for an uptrend.
            // However, his EasyLanguage code uses a descending time index (Y = -count),
            // which results in an inverted output compared to a standard Pearson correlation with an ascending time index.
            // To match the visual expectation (Up Trend = Positive Corr), we must invert our result.
            // Let's re-verify. If price (X) goes up, and our time (Y) goes up, correlation is positive. Correct.
            // If price (X) goes down, and our time (Y) goes up, correlation is negative. Correct.
            // The issue might be in the EasyLanguage indexing vs MQL5.
            // Let's try reversing the time index to match Ehlers' logic.

            // Re-calculation with reversed time index
            sx=0;
            sy=0;
            sxx=0;
            syy=0;
            sxy=0;
            for(int j = 0; j < m_period; j++)
              {
               double x = m_price[i - j];
               double y = m_period - j; // Newest bar (j=0) gets highest time value

               sx += x;
               sy += y;
               sxx += x * x;
               syy += y * y;
               sxy += x * y;
              }

            numerator = m_period * sxy - sx * sy;
            den_term1 = m_period * sxx - sx * sx;
            den_term2 = m_period * syy - sy * sy;

            if(den_term1 > 0 && den_term2 > 0)
              {
               denominator = sqrt(den_term1 * den_term2);
               if(denominator != 0)
                 {
                  corr_buffer[i] = numerator / denominator;
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
bool CCorrelationTrendCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
class CCorrelationTrendCalculator_HA : public CCorrelationTrendCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CCorrelationTrendCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
