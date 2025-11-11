//+------------------------------------------------------------------+
//|                                   Ehlers_Smoother_Calculator.mqh |
//|      VERSION 2.31: Added public GetPeriod() method.              |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

enum ENUM_SMOOTHER_TYPE { SUPERSMOOTHER, ULTIMATESMOOTHER };
enum ENUM_INPUT_SOURCE { SOURCE_PRICE, SOURCE_MOMENTUM };

//+==================================================================+
class CEhlersSmootherCalculator
  {
protected:
   int                 m_period;
   ENUM_SMOOTHER_TYPE  m_type;
   ENUM_INPUT_SOURCE   m_source_type;
   double              m_price[];
   double              m_f1, m_f2;

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CEhlersSmootherCalculator(void) : m_f1(0), m_f2(0) {};
   virtual          ~CEhlersSmootherCalculator(void) {};

   bool              Init(int period, ENUM_SMOOTHER_TYPE type, ENUM_INPUT_SOURCE source_type);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[]);

   //--- NEW: Public getter for the period
   int               GetPeriod(void) const { return m_period; }
  };

//+------------------------------------------------------------------+
bool CEhlersSmootherCalculator::Init(int period, ENUM_SMOOTHER_TYPE type, ENUM_INPUT_SOURCE source_type)
  {
   m_period = (period < 2) ? 2 : period;
   m_type = type;
   m_source_type = source_type;
   m_f1 = 0;
   m_f2 = 0; // Reset state on init
   return true;
  }

//+------------------------------------------------------------------+
void CEhlersSmootherCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[])
  {
   if(rates_total < 4)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   double a1 = exp(-M_SQRT2 * M_PI / m_period);
   double b1 = 2.0 * a1 * cos(M_SQRT2 * M_PI / m_period);
   double c2 = b1;
   double c3 = -a1 * a1;
   double c1 = (m_type == SUPERSMOOTHER) ? (1.0 - c2 - c3) : ((1.0 + c2 - c3) / 4.0);

//--- Robust initialization on first run
   if(ArraySize(filter_buffer) == 0 || filter_buffer[0] == 0)
     {
      if(rates_total > 0)
         filter_buffer[0] = m_price[0];
      if(rates_total > 1)
         filter_buffer[1] = m_price[1];
      if(rates_total > 2)
         filter_buffer[2] = m_price[2];
      m_f2 = filter_buffer[1];
      m_f1 = filter_buffer[2];
     }

   for(int i = 3; i < rates_total; i++)
     {
      double current_f = 0;
      if(m_type == SUPERSMOOTHER)
         current_f = c1 * (m_price[i] + m_price[i-1]) / 2.0 + c2 * m_f1 + c3 * m_f2;
      else
         current_f = (1.0 - c1) * m_price[i] + (2.0 * c1 - c2) * m_price[i-1] - (c1 + c3) * m_price[i-2] + c2 * m_f1 + c3 * m_f2;

      filter_buffer[i] = current_f;
      m_f2 = m_f1;
      m_f1 = current_f;
     }
  }

//+------------------------------------------------------------------+
bool CEhlersSmootherCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
class CEhlersSmootherCalculator_HA : public CEhlersSmootherCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CEhlersSmootherCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
