//+------------------------------------------------------------------+
//|                         Laguerre_Filter_Adaptive_Calculator.mqh  |
//|    VERSION 1.10: Optimized for incremental calculation.          |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|       CLASS 1: CLaguerreFilterAdaptiveCalculator (Base)          |
//+==================================================================+
class CLaguerreFilterAdaptiveCalculator
  {
protected:
   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];

   //--- Internal State Buffers for Homodyne Discriminator & Laguerre
   double            m_filt_buf[];
   double            m_I1_buf[], m_Q1_buf[];
   double            m_I2_buf[], m_Q2_buf[];
   double            m_Re_buf[], m_Im_buf[];
   double            m_Period_buf[];
   double            m_DC_Period_buf[];

   //--- Internal State Buffers for Laguerre Filter
   double            m_L0_buf[], m_L1_buf[], m_L2_buf[], m_L3_buf[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CLaguerreFilterAdaptiveCalculator(void) {};
   virtual          ~CLaguerreFilterAdaptiveCalculator(void) {};

   bool              Init(void);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreFilterAdaptiveCalculator::Init(void)
  {
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CLaguerreFilterAdaptiveCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[])
  {
   if(rates_total < 10)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Internal Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_filt_buf, rates_total);
      ArrayResize(m_I1_buf, rates_total);
      ArrayResize(m_Q1_buf, rates_total);
      ArrayResize(m_I2_buf, rates_total);
      ArrayResize(m_Q2_buf, rates_total);
      ArrayResize(m_Re_buf, rates_total);
      ArrayResize(m_Im_buf, rates_total);
      ArrayResize(m_Period_buf, rates_total);
      ArrayResize(m_DC_Period_buf, rates_total);
      ArrayResize(m_L0_buf, rates_total);
      ArrayResize(m_L1_buf, rates_total);
      ArrayResize(m_L2_buf, rates_total);
      ArrayResize(m_L3_buf, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- Constants for band-pass filter
   double alpha1 = (cos(0.707 * 2 * M_PI / 48.0) + sin(0.707 * 2 * M_PI / 48.0) - 1.0) / cos(0.707 * 2 * M_PI / 48.0);
   double beta1 = 1.0 - alpha1 / 2.0;
   beta1 *= beta1;

//--- 4. Main Loop (Incremental)
   int i = start_index;

// Initialization for first few bars
   if(i < 7) // Need at least 6 bars for Hilbert Transform lookback
     {
      // Zero out initial buffers to be safe
      for(int k=0; k<7; k++)
        {
         if(k >= rates_total)
            break;
         m_filt_buf[k] = 0;
         m_I1_buf[k] = 0;
         m_Q1_buf[k] = 0;
         m_I2_buf[k] = 0;
         m_Q2_buf[k] = 0;
         m_Re_buf[k] = 0;
         m_Im_buf[k] = 0;
         m_Period_buf[k] = 0;
         m_DC_Period_buf[k] = 0;
         m_L0_buf[k] = m_price[k];
         m_L1_buf[k] = m_price[k];
         m_L2_buf[k] = m_price[k];
         m_L3_buf[k] = m_price[k];
         filter_buffer[k] = m_price[k];
        }
      i = 7;
     }

   for(; i < rates_total; i++)
     {
      // --- Step 1: Band-Pass Filter ---
      // Uses m_filt_buf[i-1] and [i-2]
      m_filt_buf[i] = beta1 * (m_price[i] - 2 * m_price[i-1] + m_price[i-2]) +
                      (2 * (1 - alpha1 / 2.0)) * m_filt_buf[i-1] -
                      ((1 - alpha1 / 2.0) * (1 - alpha1 / 2.0)) * m_filt_buf[i-2];

      // --- Step 2: Hilbert Transform ---
      // Uses m_filt_buf[i], [i-2], [i-4], [i-6] and m_I1_buf[i-1] (stored as prev)
      // Note: Original code used I1_prev which is I1[i-1]
      m_Q1_buf[i] = (0.0962 * m_filt_buf[i] + 0.5769 * m_filt_buf[i-2] - 0.5769 * m_filt_buf[i-4] - 0.0962 * m_filt_buf[i-6]) *
                    (0.5 + 0.08 * (m_I1_buf[i-1] + 50));
      m_I1_buf[i] = m_filt_buf[i-3];

      // --- Step 3: Homodyne Discriminator ---
      m_I2_buf[i] = m_I1_buf[i] - m_Q1_buf[i-1];
      m_Q2_buf[i] = m_Q1_buf[i] + m_I1_buf[i-1];

      m_Re_buf[i] = m_I2_buf[i] * m_I2_buf[i-1] + m_Q2_buf[i] * m_Q2_buf[i-1];
      m_Im_buf[i] = m_I2_buf[i] * m_Q2_buf[i-1] - m_Q2_buf[i] * m_I2_buf[i-1];

      // Smooth Re/Im
      m_Re_buf[i] = 0.2 * m_Re_buf[i] + 0.8 * m_Re_buf[i-1];
      m_Im_buf[i] = 0.2 * m_Im_buf[i] + 0.8 * m_Im_buf[i-1];

      double Period = 0;
      if(m_Im_buf[i] != 0.0 && m_Re_buf[i] != 0.0)
         Period = 2 * M_PI / atan(m_Im_buf[i] / m_Re_buf[i]);

      // --- Step 4: Clean up Period ---
      if(Period > 1.5 * m_Period_buf[i-1])
         Period = 1.5 * m_Period_buf[i-1];
      if(Period < 0.67 * m_Period_buf[i-1])
         Period = 0.67 * m_Period_buf[i-1];
      if(Period < 6)
         Period = 6;
      if(Period > 50)
         Period = 50;

      m_Period_buf[i] = 0.2 * Period + 0.8 * m_Period_buf[i-1];
      m_DC_Period_buf[i] = 0.33 * Period + 0.67 * m_DC_Period_buf[i-1]; // Using standard smoothing for DC

      // --- Step 5: Adaptive Gamma ---
      double gamma = 0.0;
      if(m_DC_Period_buf[i] > 0)
         gamma = 4.0 / m_DC_Period_buf[i]; // Tuning factor can be adjusted

      // --- Step 6: Laguerre Filter ---
      double L0_prev = m_L0_buf[i-1];
      double L1_prev = m_L1_buf[i-1];
      double L2_prev = m_L2_buf[i-1];
      double L3_prev = m_L3_buf[i-1];

      m_L0_buf[i] = (1.0 - gamma) * m_price[i] + gamma * L0_prev;
      m_L1_buf[i] = -gamma * m_L0_buf[i] + L0_prev + gamma * L1_prev;
      m_L2_buf[i] = -gamma * m_L1_buf[i] + L1_prev + gamma * L2_prev;
      m_L3_buf[i] = -gamma * m_L2_buf[i] + L2_prev + gamma * L3_prev;

      filter_buffer[i] = (m_L0_buf[i] + 2.0 * m_L1_buf[i] + 2.0 * m_L2_buf[i] + m_L3_buf[i]) / 6.0;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CLaguerreFilterAdaptiveCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Optimized copy loop
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
            m_price[i] = (high[i]+low[i]+close[i]+close[i])/4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CLaguerreFilterAdaptiveCalculator_HA        |
//+==================================================================+
class CLaguerreFilterAdaptiveCalculator_HA : public CLaguerreFilterAdaptiveCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CLaguerreFilterAdaptiveCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

//--- Copy to m_price (Optimized loop)
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
