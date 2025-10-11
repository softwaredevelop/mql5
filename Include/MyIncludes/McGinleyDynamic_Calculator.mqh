//+------------------------------------------------------------------+
//|                                 McGinleyDynamic_Calculator.mqh   |
//| Calculation engine for Standard and Heikin Ashi McGinley Dynamic.|
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//| CLASS: CMcGinleyFilter                                           |
//| A stateful class to calculate one instance of a McGinley filter. |
//+==================================================================+
class CMcGinleyFilter
  {
private:
   int               m_length;
   double            m_last_value;
   bool              m_is_initialized;

public:
                     CMcGinleyFilter(void) : m_length(14), m_last_value(0), m_is_initialized(false) {}

   void              Init(int length);
   double            Update(double price, const double &price_series[], int current_index);
  };

//+------------------------------------------------------------------+
//| CMcGinleyFilter: Resets the filter's state.                      |
//+------------------------------------------------------------------+
void CMcGinleyFilter::Init(int length)
  {
   m_length = (length < 1) ? 1 : length;
   m_is_initialized = false; // Reset initialization flag
   m_last_value = 0;
  }

//+------------------------------------------------------------------+
//| CMcGinleyFilter: Updates the filter with a new price value.      |
//+------------------------------------------------------------------+
double CMcGinleyFilter::Update(double price, const double &price_series[], int current_index)
  {
//--- Robust initialization with SMA on the first valid call
   if(!m_is_initialized)
     {
      // Not enough data to calculate initial SMA
      if(current_index < m_length - 1)
         return EMPTY_VALUE;

      double sum = 0;
      for(int i = 0; i < m_length; i++)
        {
         sum += price_series[current_index - i];
        }

      if(m_length > 0)
         m_last_value = sum / m_length;
      else
         m_last_value = price;

      m_is_initialized = true;
      return m_last_value;
     }

//--- Handle potential zero or negative previous values
   if(m_last_value <= 0)
     {
      m_last_value = price;
      return m_last_value;
     }

//--- Robust calculation with ratio clamping to prevent overflow ---
   double ratio = price / m_last_value;

// Clamp the ratio to prevent extreme 'k' values on volatile instruments
   if(ratio > 2.0)
      ratio = 2.0; // Cap ratio at 100% price increase
   if(ratio < 0.5)
      ratio = 0.5; // Cap ratio at 50% price decrease

   double k = m_length * MathPow(ratio, 4);

// Final guard clause to ensure the dynamic period is at least 1
   if(k < 1.0)
      k = 1.0;

   m_last_value = m_last_value + (price - m_last_value) / k;
   return m_last_value;
  }

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
   if(rates_total < m_length)
      return;
   if(!PreparePriceSeries(rates_total, open, high, low, close, price_type))
      return;

   CMcGinleyFilter filter;
   filter.Init(m_length);

   for(int i = 0; i < rates_total; i++)
     {
      mcginley_buffer[i] = filter.Update(m_price[i], m_price, i);
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
