//+------------------------------------------------------------------+
//|                                               CMO_Calculator.mqh |
//|          Calculation engine for Standard and Heikin Ashi CMO.    |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|               CLASS 1: CCMOCalculator (Base Class)               |
//|                                                                  |
//+==================================================================+
class CCMOCalculator
  {
protected:
   int               m_cmo_period;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CCMOCalculator(void) {};
   virtual          ~CCMOCalculator(void) {};

   bool              Init(int cmo_p);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &cmo_buffer[]);
  };

//+------------------------------------------------------------------+
//| CCMOCalculator: Initialization                                   |
//+------------------------------------------------------------------+
bool CCMOCalculator::Init(int cmo_p)
  {
   m_cmo_period = (cmo_p < 1) ? 1 : cmo_p;
   return true;
  }

//+------------------------------------------------------------------+
//| CCMOCalculator: Main Calculation Method (Shared Logic)           |
//+------------------------------------------------------------------+
void CCMOCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &cmo_buffer[])
  {
   if(rates_total <= m_cmo_period)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   for(int i = m_cmo_period; i < rates_total; i++)
     {
      double sum_up = 0.0, sum_down = 0.0;
      for(int j = 0; j < m_cmo_period; j++)
        {
         double diff = m_price[i - j] - m_price[i - j - 1];
         if(diff > 0.0)
            sum_up += diff;
         else
            sum_down += (-diff);
        }

      double total_sum = sum_up + sum_down;
      if(total_sum == 0.0)
         cmo_buffer[i] = 0.0;
      else
         cmo_buffer[i] = 100.0 * (sum_up - sum_down) / total_sum;
     }
  }

//+------------------------------------------------------------------+
//| CCMOCalculator: Prepares the standard source price.              |
//+------------------------------------------------------------------+
bool CCMOCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|             CLASS 2: CCMOCalculator_HA (Heikin Ashi)             |
//|                                                                  |
//+==================================================================+
class CCMOCalculator_HA : public CCMOCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CCMOCalculator_HA: Prepares the HA source price.                 |
//+------------------------------------------------------------------+
bool CCMOCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
