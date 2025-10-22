//+------------------------------------------------------------------+
//|                                             DSMA_Calculator.mqh  |
//|      Calculation engine for the John Ehlers' DSMA.               |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CDSMACalculator (Base Class)                |
//|                                                                  |
//+==================================================================+
class CDSMACalculator
  {
protected:
   int               m_period;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CDSMACalculator(void) {};
   virtual          ~CDSMACalculator(void) {};

   bool              Init(int period);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &dsma_buffer[]);
  };

//+------------------------------------------------------------------+
bool CDSMACalculator::Init(int period)
  {
   m_period = (period < 4) ? 4 : period;
   return true;
  }

//+------------------------------------------------------------------+
void CDSMACalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &dsma_buffer[])
  {
   if(rates_total < m_period + 2)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

// --- Intermediate buffers ---
   double zeros_buffer[], filt_buffer[];
   ArrayResize(zeros_buffer, rates_total);
   ArrayResize(filt_buffer, rates_total);

// --- Step 1: Calculate "Zeros" oscillator ---
   for(int i = 2; i < rates_total; i++)
     {
      zeros_buffer[i] = m_price[i] - m_price[i-2];
     }

// --- Step 2: Smooth "Zeros" with a SuperSmoother ---
// Coefficients for SuperSmoother with Period/2
   int    ss_period = m_period / 2;
   double arg = 1.414 * M_PI / ss_period;
   double a1 = exp(-arg);
   double b1 = 2.0 * a1 * cos(arg);
   double c2 = b1;
   double c3 = -a1 * a1;
   double c1 = 1.0 - c2 - c3;

   double filt1=0, filt2=0; // Previous values for SuperSmoother
   for(int i = 2; i < rates_total; i++)
     {
      filt_buffer[i] = c1 * (zeros_buffer[i] + zeros_buffer[i-1]) / 2.0 + c2 * filt1 + c3 * filt2;
      filt2 = filt1;
      filt1 = filt_buffer[i];
     }

// --- Steps 3-6: Calculate RMS, Alpha, and final DSMA ---
   double dsma_prev = 0;
   for(int i = m_period + 1; i < rates_total; i++)
     {
      // Step 3: Compute RMS (Standard Deviation)
      double rms = 0;
      for(int j = 0; j < m_period; j++)
        {
         rms += filt_buffer[i-j] * filt_buffer[i-j];
        }
      rms = sqrt(rms / m_period);

      // Step 4: Rescale Filt in terms of Standard Deviations
      double scaled_filt = 0;
      if(rms != 0)
         scaled_filt = filt_buffer[i] / rms;

      // Step 5: Calculate adaptive alpha
      double alpha1 = fabs(scaled_filt) * 5.0 / m_period;
      // Clamp alpha to prevent instability
      if(alpha1 > 1.0)
         alpha1 = 1.0;
      if(alpha1 < 2.0 / (m_period + 1.0))
         alpha1 = 2.0 / (m_period + 1.0); // Prevent it from being too slow

      // Step 6: Calculate final DSMA value
      if(i == m_period + 1)
         dsma_prev = m_price[i]; // Initialize first value
      dsma_buffer[i] = alpha1 * m_price[i] + (1.0 - alpha1) * dsma_prev;
      dsma_prev = dsma_buffer[i];
     }
  }

//+------------------------------------------------------------------+
bool CDSMACalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
class CDSMACalculator_HA : public CDSMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CDSMACalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
