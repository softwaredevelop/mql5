//+------------------------------------------------------------------+
//|                                      BandStop_Calculator.mqh     |
//|      Calculation engine for the John Ehlers' Band-Stop Filter.   |
//|      Implemented by subtracting BandPass from Price.             |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CBandStopCalculator (Base Class)              |
//|                                                                  |
//+==================================================================+
class CBandStopCalculator
  {
protected:
   double            m_price[];

   // Filter parameters
   int               m_period;
   double            m_bandwidth;

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CBandStopCalculator(void) {};
   virtual          ~CBandStopCalculator(void) {};

   bool              Init(int period, double bandwidth_delta);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[]);
  };

//+------------------------------------------------------------------+
bool CBandStopCalculator::Init(int period, double bandwidth_delta)
  {
   m_period = (period < 2) ? 2 : period;
   m_bandwidth = bandwidth_delta;
   if(m_bandwidth <= 0 || m_bandwidth >= 0.5)
     {
      Print("BandStop Filter: Invalid bandwidth. Must be > 0 and < 0.5");
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
void CBandStopCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[])
  {
   if(rates_total < 3)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

// --- Calculate Band-Pass filter first ---
   double bp_buffer[];
   ArrayResize(bp_buffer, rates_total);

// Band-Pass coefficients
   double beta = cos(2.0 * M_PI / m_period);
   double gamma = 1.0 / cos(4.0 * M_PI * m_bandwidth / m_period);
   double alpha = gamma - sqrt(gamma * gamma - 1.0);
   double c0 = (1.0 - alpha) / 2.0;
   double a1 = beta * (1.0 + alpha);
   double a2 = -alpha;

// State variables for Band-Pass recursion
   double bp1=0, bp2=0;

   for(int i = 2; i < rates_total; i++)
     {
      // Band-Pass formula: BP = c0*(Price - Price[2]) + a1*BP[1] + a2*BP[2]
      double current_bp = c0 * (m_price[i] - m_price[i-2]) + a1 * bp1 + a2 * bp2;
      bp_buffer[i] = current_bp;

      // Update state
      bp2 = bp1;
      bp1 = current_bp;

      // --- Final Step: Calculate Band-Stop by subtraction ---
      filter_buffer[i] = m_price[i] - bp_buffer[i];
     }

// Initialize early values
   filter_buffer[0] = m_price[0];
   filter_buffer[1] = m_price[1];
  }

//+------------------------------------------------------------------+
bool CBandStopCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CBandStopCalculator_HA : public CBandStopCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CBandStopCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
