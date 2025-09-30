//+------------------------------------------------------------------+
//|                                 McGinleyDynamic_Calculator.mqh   |
//| Calculation engine for Standard and Heikin Ashi McGinley Dynamic.|
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|         CLASS 1: CMcGinleyDynamicCalculator (Base Class)         |
//|                                                                  |
//+==================================================================+
class CMcGinleyDynamicCalculator
  {
protected:
   int               m_length;
   double            m_price[];

   //--- Virtual method for preparing the price series.
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

public:
                     CMcGinleyDynamicCalculator(void) {};
   virtual          ~CMcGinleyDynamicCalculator(void) {};

   bool              Init(int length);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &mcginley_buffer[]);
  };

//+------------------------------------------------------------------+
//| CMcGinleyDynamicCalculator: Initialization                       |
//+------------------------------------------------------------------+
bool CMcGinleyDynamicCalculator::Init(int length)
  {
   m_length = (length < 1) ? 1 : length;
   return true;
  }

//+------------------------------------------------------------------+
//| CMcGinleyDynamicCalculator: Main Calculation Method (Shared Logic)|
//+------------------------------------------------------------------+
void CMcGinleyDynamicCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &mcginley_buffer[])
  {
   if(rates_total < 2)
      return;
   if(!PreparePriceSeries(rates_total, open, high, low, close, price_type))
      return;

   for(int i = 0; i < rates_total; i++)
     {
      if(i == 0)
        {
         mcginley_buffer[i] = m_price[i];
         continue;
        }

      double prev_mg = mcginley_buffer[i-1];
      if(prev_mg == 0)
        {
         mcginley_buffer[i] = m_price[i];
         continue;
        }

      double denominator = m_length * MathPow(m_price[i] / prev_mg, 4);
      if(denominator == 0)
        {
         mcginley_buffer[i] = prev_mg;
         continue;
        }

      mcginley_buffer[i] = prev_mg + (m_price[i] - prev_mg) / denominator;
     }
  }

//+------------------------------------------------------------------+
//| CMcGinleyDynamicCalculator: Prepares the standard source price.  |
//+------------------------------------------------------------------+
bool CMcGinleyDynamicCalculator::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   ArrayResize(m_price, rates_total);
   switch(price_type)
     {
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
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
     }
   return true;
  }

//+==================================================================+
//|                                                                  |
//|       CLASS 2: CMcGinleyDynamicCalculator_HA (Heikin Ashi)       |
//|                                                                  |
//+==================================================================+
class CMcGinleyDynamicCalculator_HA : public CMcGinleyDynamicCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| CMcGinleyDynamicCalculator_HA: Prepares the HA source price.     |
//+------------------------------------------------------------------+
bool CMcGinleyDynamicCalculator_HA::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
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
            m_price[i] = (ha_high[i]+ha_low[i]+2*ha_close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
