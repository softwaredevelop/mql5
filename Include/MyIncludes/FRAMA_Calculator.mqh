//+------------------------------------------------------------------+
//|                                             FRAMA_Calculator.mqh |
//|      Calculation engine for the John Ehlers' FRAMA.              |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CFRAMACalculator (Base Class)               |
//|                                                                  |
//+==================================================================+
class CFRAMACalculator
  {
protected:
   int               m_period;
   double            m_price[], m_high[], m_low[];

   virtual bool      PrepareSourceData(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CFRAMACalculator(void) {};
   virtual          ~CFRAMACalculator(void) {};

   bool              Init(int period);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &frama_buffer[]);
  };

//+------------------------------------------------------------------+
bool CFRAMACalculator::Init(int period)
  {
// N must be an even number
   m_period = (period < 4) ? 4 : period;
   if(m_period % 2 != 0)
      m_period++;
   return true;
  }

//+------------------------------------------------------------------+
void CFRAMACalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &frama_buffer[])
  {
   if(rates_total < m_period + 1)
      return;
   if(!PrepareSourceData(rates_total, price_type, open, high, low, close))
      return;

   double frama_prev = 0;
   int half_period = m_period / 2;

   for(int i = m_period; i < rates_total; i++)
     {
      // Step 1: Calculate N1, N2, N3
      int high_idx1 = ArrayMaximum(m_high, i - half_period + 1, half_period);
      int low_idx1  = ArrayMinimum(m_low, i - half_period + 1, half_period);
      double n1 = (m_high[high_idx1] - m_low[low_idx1]) / half_period;

      int high_idx2 = ArrayMaximum(m_high, i - m_period + 1, half_period);
      int low_idx2  = ArrayMinimum(m_low, i - m_period + 1, half_period);
      double n2 = (m_high[high_idx2] - m_low[low_idx2]) / half_period;

      int high_idx3 = ArrayMaximum(m_high, i - m_period + 1, m_period);
      int low_idx3  = ArrayMinimum(m_low, i - m_period + 1, m_period);
      double n3 = (m_high[high_idx3] - m_low[low_idx3]) / m_period;

      // Step 2: Calculate Fractal Dimension (Dimen)
      double dimen = 0.0;
      if(n1 > 0 && n2 > 0 && n3 > 0)
        {
         dimen = (log(n1 + n2) - log(n3)) / log(2.0);
        }

      // Step 3: Calculate adaptive alpha
      double alpha = exp(-4.6 * (dimen - 1.0));
      if(alpha < 0.01)
         alpha = 0.01;
      if(alpha > 1.0)
         alpha = 1.0;

      // Step 4: Calculate FRAMA
      double current_frama = alpha * m_price[i] + (1.0 - alpha) * frama_prev;
      frama_buffer[i] = current_frama;

      frama_prev = current_frama;
     }

// Initialization for the first value
   if(rates_total > m_period)
      frama_buffer[m_period] = m_price[m_period];
  }

//+------------------------------------------------------------------+
bool CFRAMACalculator::PrepareSourceData(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);
   ArrayResize(m_high, rates_total);
   ArrayResize(m_low, rates_total);
   ArrayCopy(m_high, high, 0, 0, rates_total);
   ArrayCopy(m_low, low, 0, 0, rates_total);

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
class CFRAMACalculator_HA : public CFRAMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PrepareSourceData(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CFRAMACalculator_HA::PrepareSourceData(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayCopy(m_high, ha_high, 0, 0, rates_total);
   ArrayCopy(m_low, ha_low, 0, 0, rates_total);

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
