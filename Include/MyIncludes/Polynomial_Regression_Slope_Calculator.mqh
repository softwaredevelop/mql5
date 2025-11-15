//+------------------------------------------------------------------+
//|                   Polynomial_Regression_Slope_Calculator.mqh     |
//|      Engine for the Polynomial Regression Slope oscillator.      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
class CPolynomialRegressionSlopeCalculator
  {
protected:
   int               m_period;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CPolynomialRegressionSlopeCalculator(void) {};
   virtual          ~CPolynomialRegressionSlopeCalculator(void) {};

   bool              Init(int period);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &slope_buffer[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CPolynomialRegressionSlopeCalculator_HA : public CPolynomialRegressionSlopeCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  }; // Full definition below

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CPolynomialRegressionSlopeCalculator::Init(int period)
  {
   m_period = (period < 3) ? 3 : period;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CPolynomialRegressionSlopeCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &slope_buffer[])
  {
   if(rates_total < m_period)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   int start_pos = m_period - 1;

   for(int i = start_pos; i < rates_total; i++)
     {
      double sum_x=0, sum_y=0, sum_x2=0, sum_xy=0, sum_x3=0, sum_x4=0, sum_x2y=0;
      for(int j = 0; j < m_period; j++)
        {
         double x = j;
         double y = m_price[i - m_period + 1 + j];
         sum_x += x;
         sum_y += y;
         sum_x2 += x*x;
         sum_xy += x*y;
         sum_x3 += x*x*x;
         sum_x4 += x*x*x*x;
         sum_x2y += x*x*y;
        }

      double b=0, c=0;
      double n = m_period;

      double D = n * (sum_x2 * sum_x4 - sum_x3 * sum_x3) - sum_x * (sum_x * sum_x4 - sum_x2 * sum_x3) + sum_x2 * (sum_x * sum_x3 - sum_x2 * sum_x2);
      if(MathAbs(D) < 1e-10)
         continue;

      double Db = n * (sum_xy * sum_x4 - sum_x2y * sum_x3) - sum_x * (sum_y * sum_x4 - sum_x2 * sum_x2y) + sum_x2 * (sum_y * sum_x3 - sum_x2 * sum_xy);
      double Dc = n * (sum_x2 * sum_x2y - sum_x3 * sum_xy) - sum_x * (sum_x * sum_x2y - sum_x2 * sum_xy) + sum_y * (sum_x * sum_x3 - sum_x2 * sum_x2);

      b = Db / D;
      c = Dc / D;

      //--- Calculate the slope at the current bar (x = n - 1)
      double x_current = n - 1;
      slope_buffer[i] = b + 2 * c * x_current;
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CPolynomialRegressionSlopeCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
bool CPolynomialRegressionSlopeCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
