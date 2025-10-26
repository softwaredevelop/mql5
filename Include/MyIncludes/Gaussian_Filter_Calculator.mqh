//+------------------------------------------------------------------+
//|                                   Gaussian_Filter_Calculator.mqh |
//|      Calculation engine for the John Ehlers' Gaussian Filter.    |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CGaussianFilterCalculator (Base Class)        |
//|                                                                  |
//+==================================================================+
class CGaussianFilterCalculator
  {
protected:
   int               m_period;
   double            m_price[];

   // Filter coefficients
   double            c0, a1, a2;

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CGaussianFilterCalculator(void) {};
   virtual          ~CGaussianFilterCalculator(void) {};

   bool              Init(int period);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[]);
  };

//+------------------------------------------------------------------+
bool CGaussianFilterCalculator::Init(int period)
  {
   m_period = (period < 2) ? 2 : period;

// Pre-calculate filter coefficients based on Ehlers' formulas
   double beta = 2.415 * (1.0 - cos(2.0 * M_PI / m_period));
   double alpha = -beta + sqrt(beta * beta + 2.0 * beta);

   c0 = alpha * alpha;
   a1 = 2.0 * (1.0 - alpha);
   a2 = -pow(1.0 - alpha, 2);

   return true;
  }

//+------------------------------------------------------------------+
void CGaussianFilterCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[])
  {
   if(rates_total < 3)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

// --- State variables for recursive calculation ---
   double f1=0, f2=0; // f[1], f[2]

// --- Initialization for the first few bars ---
   filter_buffer[0] = m_price[0];
   filter_buffer[1] = m_price[1];
   f1 = filter_buffer[1];
   f2 = filter_buffer[0];

// --- Full recalculation loop for stability ---
   for(int i = 2; i < rates_total; i++)
     {
      double current_f = c0 * m_price[i] + a1 * f1 + a2 * f2;
      filter_buffer[i] = current_f;

      // Update state for next iteration
      f2 = f1;
      f1 = current_f;
     }
  }

//+------------------------------------------------------------------+
bool CGaussianFilterCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
class CGaussianFilterCalculator_HA : public CGaussianFilterCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CGaussianFilterCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
