//+------------------------------------------------------------------+
//|                                              ALMA_Calculator.mqh |
//|        Calculation engine for Standard and Heikin Ashi ALMA.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CALMACalculator (Base Class)                |
//|                                                                  |
//+==================================================================+
class CALMACalculator
  {
protected:
   int               m_alma_period;
   double            m_alma_offset;
   double            m_alma_sigma;

   //--- Internal buffer for the selected source price
   double            m_price[];

   //--- Virtual method for preparing the price series. Base class handles standard prices.
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CALMACalculator(void) {};
   virtual          ~CALMACalculator(void) {};

   //--- Public methods
   bool              Init(int period, double offset, double sigma);
   int               GetPeriod(void) const { return m_alma_period; }
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &alma_buffer[]);
  };

//+------------------------------------------------------------------+
//| CALMACalculator: Initialization                                  |
//+------------------------------------------------------------------+
bool CALMACalculator::Init(int period, double offset, double sigma)
  {
   m_alma_period = (period < 1) ? 1 : period;
   m_alma_offset = offset;
   m_alma_sigma  = (sigma <= 0) ? 0.01 : sigma;
   return true;
  }

//+------------------------------------------------------------------+
//| CALMACalculator: Main Calculation Method (Shared Logic)          |
//+------------------------------------------------------------------+
void CALMACalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &alma_buffer[])
  {
   if(rates_total < m_alma_period)
      return;

//--- STEP 1: Prepare the source price array (delegated to virtual method)
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

//--- STEP 2: Core ALMA calculation using the prepared m_price[] array
   double m = m_alma_offset * (m_alma_period - 1.0);
   double s = (double)m_alma_period / m_alma_sigma;

   for(int i = m_alma_period - 1; i < rates_total; i++)
     {
      double sum = 0.0;
      double norm = 0.0;

      for(int j = 0; j < m_alma_period; j++)
        {
         double weight = MathExp(-1 * MathPow(j - m, 2) / (2 * s * s));
         int price_index = i - (m_alma_period - 1) + j;

         sum += m_price[price_index] * weight;
         norm += weight;
        }

      if(norm > 0)
         alma_buffer[i] = sum / norm;
      else
         alma_buffer[i] = 0.0;
     }
  }

//+------------------------------------------------------------------+
//| CALMACalculator: Prepares the standard source price series.      |
//+------------------------------------------------------------------+
bool CALMACalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
         for(int i = 0; i < rates_total; i++)
            m_price[i] = (high[i] + low[i]) / 2.0;
         break;
      case PRICE_TYPICAL:
         for(int i = 0; i < rates_total; i++)
            m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i = 0; i < rates_total; i++)
            m_price[i] = (high[i] + low[i] + 2 * close[i]) / 4.0;
         break;
      default: // PRICE_CLOSE
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
     }
   return true;
  }

//+==================================================================+
//|                                                                  |
//|             CLASS 2: CALMACalculator_HA (Heikin Ashi)            |
//|                                                                  |
//+==================================================================+
class CALMACalculator_HA : public CALMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator; // Instance of the HA calculator tool

protected:
   //--- Overridden method to prepare Heikin Ashi price series
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CALMACalculator_HA: Prepares the Heikin Ashi source price series.|
//+------------------------------------------------------------------+
bool CALMACalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
//--- Intermediate buffers for HA candles
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- Calculate the HA candles first
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- Now, populate the m_price array from the calculated HA candles
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
         for(int i = 0; i < rates_total; i++)
            m_price[i] = (ha_high[i] + ha_low[i]) / 2.0;
         break;
      case PRICE_TYPICAL:
         for(int i = 0; i < rates_total; i++)
            m_price[i] = (ha_high[i] + ha_low[i] + ha_close[i]) / 3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i = 0; i < rates_total; i++)
            m_price[i] = (ha_high[i] + ha_low[i] + 2 * ha_close[i]) / 4.0;
         break;
      default: // PRICE_CLOSE
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
