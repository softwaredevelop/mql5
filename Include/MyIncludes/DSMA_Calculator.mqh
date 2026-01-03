//+------------------------------------------------------------------+
//|                                             DSMA_Calculator.mqh  |
//|      Calculation engine for the John Ehlers' DSMA.               |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CDSMACalculator (Base Class)                |
//+==================================================================+
class CDSMACalculator
  {
protected:
   int               m_period;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];
   double            m_zeros[]; // Zeros oscillator
   double            m_filt[];  // Smoothed Zeros

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CDSMACalculator(void) {};
   virtual          ~CDSMACalculator(void) {};

   bool              Init(int period);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &dsma_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CDSMACalculator::Init(int period)
  {
   m_period = (period < 4) ? 4 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CDSMACalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &dsma_buffer[])
  {
   if(rates_total < m_period + 2)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_zeros, rates_total);
      ArrayResize(m_filt, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Calculate "Zeros" oscillator (Incremental)
   int loop_start_zeros = MathMax(2, start_index);

   for(int i = loop_start_zeros; i < rates_total; i++)
     {
      m_zeros[i] = m_price[i] - m_price[i-2];
     }

//--- 5. Smooth "Zeros" with a SuperSmoother (Incremental)
   int    ss_period = m_period / 2;
   double arg = M_SQRT2 * M_PI / ss_period;
   double a1 = exp(-arg);
   double b1 = 2.0 * a1 * cos(arg);
   double c2 = b1;
   double c3 = -a1 * a1;
   double c1 = 1.0 - c2 - c3;

   int loop_start_filt = MathMax(2, start_index);

   if(loop_start_filt == 2)
     {
      m_filt[0] = 0;
      m_filt[1] = 0;
     }

   for(int i = loop_start_filt; i < rates_total; i++)
     {
      // Recursive calculation using persistent buffer [i-1], [i-2]
      m_filt[i] = c1 * (m_zeros[i] + m_zeros[i-1]) / 2.0 + c2 * m_filt[i-1] + c3 * m_filt[i-2];
     }

//--- 6. Calculate DSMA (Incremental)
   int loop_start_dsma = MathMax(m_period + 1, start_index);

   if(prev_calculated == 0)
     {
      // Initialize first value
      dsma_buffer[m_period] = m_price[m_period];
     }

   for(int i = loop_start_dsma; i < rates_total; i++)
     {
      // Step 3: Compute RMS (Standard Deviation)
      // Optimization: For large periods, a sliding window sum of squares would be faster.
      // But for standard periods (40), a loop is acceptable.
      double sum_sq = 0;
      for(int j = 0; j < m_period; j++)
        {
         sum_sq += m_filt[i-j] * m_filt[i-j];
        }
      double rms = sqrt(sum_sq / m_period);

      // Step 4: Rescale Filt
      double scaled_filt = 0;
      if(rms != 0)
         scaled_filt = m_filt[i] / rms;

      // Step 5: Calculate adaptive alpha
      double alpha1 = fabs(scaled_filt) * 5.0 / m_period;

      // Clamp alpha
      if(alpha1 > 1.0)
         alpha1 = 1.0;
      // Prevent it from being too slow (optional, but recommended by Ehlers)
      // if(alpha1 < 2.0 / (m_period + 1.0)) alpha1 = 2.0 / (m_period + 1.0);

      // Step 6: Calculate final DSMA value (Recursive EMA)
      // Use dsma_buffer[i-1] which is persistent
      dsma_buffer[i] = alpha1 * m_price[i] + (1.0 - alpha1) * dsma_buffer[i-1];
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CDSMACalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = high[i];
            break;
         case PRICE_LOW:
            m_price[i] = low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (high[i]+low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CDSMACalculator_HA (Heikin Ashi)            |
//+==================================================================+
class CDSMACalculator_HA : public CDSMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];
protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CDSMACalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = m_ha_close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = m_ha_open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = m_ha_high[i];
            break;
         case PRICE_LOW:
            m_price[i] = m_ha_low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (m_ha_high[i]+m_ha_low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+m_ha_close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+2*m_ha_close[i])/4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
