//+------------------------------------------------------------------+
//|                                     Butterworth_Calculator.mqh   |
//|      Calculation engine for the John Ehlers' Butterworth Filter. |
//|      Can be applied to Price or Momentum.                        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

enum ENUM_BUTTERWORTH_POLES { POLES_TWO = 2, POLES_THREE = 3 };
enum ENUM_INPUT_SOURCE { SOURCE_PRICE, SOURCE_MOMENTUM };

//+==================================================================+
class CButterworthCalculator
  {
protected:
   int                     m_period;
   ENUM_BUTTERWORTH_POLES  m_poles;
   ENUM_INPUT_SOURCE       m_source_type;
   double                  m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CButterworthCalculator(void) {};
   virtual          ~CButterworthCalculator(void) {};

   bool              Init(int period, ENUM_BUTTERWORTH_POLES poles, ENUM_INPUT_SOURCE source_type);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[]);
  };

//+------------------------------------------------------------------+
bool CButterworthCalculator::Init(int period, ENUM_BUTTERWORTH_POLES poles, ENUM_INPUT_SOURCE source_type)
  {
   m_period = (period < 2) ? 2 : period;
   m_poles = poles;
   m_source_type = source_type;
   return true;
  }

//+------------------------------------------------------------------+
void CButterworthCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[])
  {
   if(rates_total < m_period)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   double f1=0, f2=0, f3=0;

   if(m_poles == POLES_TWO)
     {
      double a = exp(-1.414 * M_PI / m_period);
      double b = 2.0 * a * cos(1.414 * M_PI / m_period);
      double c1 = (1.0 - b + a*a) / 4.0;
      for(int i = 2; i < rates_total; i++)
        {
         double current_f = b * f1 - a * a * f2 + c1 * (m_price[i] + 2.0 * m_price[i-1] + m_price[i-2]);
         filter_buffer[i] = current_f;
         f2 = f1;
         f1 = current_f;
        }
     }
   else // POLES_THREE
     {
      double a = exp(-M_PI / m_period);
      double b = 2.0 * a * cos(1.738 * M_PI / m_period);
      double c = a * a;
      double c1 = (1.0 - b + c) * (1.0 - c) / 8.0;
      for(int i = 3; i < rates_total; i++)
        {
         double current_f = (b + c) * f1 - (c + b*c) * f2 + c*c * f3 + c1 * (m_price[i] + 3.0 * m_price[i-1] + 3.0 * m_price[i-2] + m_price[i-3]);
         filter_buffer[i] = current_f;
         f3 = f2;
         f2 = f1;
         f1 = current_f;
        }
     }
  }

//+------------------------------------------------------------------+
bool CButterworthCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);
   if(m_source_type == SOURCE_PRICE)
     {
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
     }
   else // SOURCE_MOMENTUM
     {
      for(int i=0; i<rates_total; i++)
         m_price[i] = close[i] - open[i];
     }
   return true;
  }

//+==================================================================+
class CButterworthCalculator_HA : public CButterworthCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CButterworthCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_price, rates_total);
   if(m_source_type == SOURCE_PRICE)
     {
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
     }
   else // SOURCE_MOMENTUM
     {
      for(int i=0; i<rates_total; i++)
         m_price[i] = ha_close[i] - ha_open[i];
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
