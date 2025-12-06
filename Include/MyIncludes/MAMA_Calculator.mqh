//+------------------------------------------------------------------+
//|                                              MAMA_Calculator.mqh |
//|      VERSION 1.30: Restored Incremental Calculation (Verified).  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CMAMACalculator (Base Class)                |
//+==================================================================+
class CMAMACalculator
  {
protected:
   double            m_fast_limit;
   double            m_slow_limit;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];

   //--- Internal State Buffers
   double            m_smooth_buf[];
   double            m_detrender_buf[];
   double            m_I1_buf[], m_Q1_buf[];
   double            m_jI_buf[], m_jQ_buf[];
   double            m_I2_buf[], m_Q2_buf[];
   double            m_Re_buf[], m_Im_buf[];
   double            m_period_buf[];
   double            m_smooth_period_buf[];
   double            m_phase_buf[];
   double            m_mama_buf[];
   double            m_fama_buf[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CMAMACalculator(void) {};
   virtual          ~CMAMACalculator(void) {};

   bool              Init(double fast_limit, double slow_limit);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &mama_buffer[], double &fama_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMAMACalculator::Init(double fast_limit, double slow_limit)
  {
   m_fast_limit = fast_limit;
   m_slow_limit = slow_limit;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CMAMACalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                double &mama_buffer[], double &fama_buffer[])
  {
   if(rates_total < 50)
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
      ArrayResize(m_smooth_buf, rates_total);
      ArrayResize(m_detrender_buf, rates_total);
      ArrayResize(m_I1_buf, rates_total);
      ArrayResize(m_Q1_buf, rates_total);
      ArrayResize(m_jI_buf, rates_total);
      ArrayResize(m_jQ_buf, rates_total);
      ArrayResize(m_I2_buf, rates_total);
      ArrayResize(m_Q2_buf, rates_total);
      ArrayResize(m_Re_buf, rates_total);
      ArrayResize(m_Im_buf, rates_total);
      ArrayResize(m_period_buf, rates_total);
      ArrayResize(m_smooth_period_buf, rates_total);
      ArrayResize(m_phase_buf, rates_total);
      ArrayResize(m_mama_buf, rates_total);
      ArrayResize(m_fama_buf, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Main Loop (Incremental)
   int i = start_index;

// Initialization
   if(i < 7)
     {
      for(int k=0; k<7; k++)
        {
         if(k >= rates_total)
            break;
         m_smooth_buf[k] = 0;
         m_detrender_buf[k] = 0;
         m_I1_buf[k] = 0;
         m_Q1_buf[k] = 0;
         m_jI_buf[k] = 0;
         m_jQ_buf[k] = 0;
         m_I2_buf[k] = 0;
         m_Q2_buf[k] = 0;
         m_Re_buf[k] = 0;
         m_Im_buf[k] = 0;
         m_period_buf[k] = 0;
         m_smooth_period_buf[k] = 0;
         m_phase_buf[k] = 0;
         m_mama_buf[k] = m_price[k];
         m_fama_buf[k] = m_price[k];
         mama_buffer[k] = m_price[k];
         fama_buffer[k] = m_price[k];
        }
      i = 7;
     }

   for(; i < rates_total; i++)
     {
      // 1. Smoothing
      m_smooth_buf[i] = (4*m_price[i] + 3*m_price[i-1] + 2*m_price[i-2] + m_price[i-3]) / 10.0;

      // 2. Detrender
      double period_prev = m_period_buf[i-1];
      m_detrender_buf[i] = (0.0962*m_smooth_buf[i] + 0.5769*m_smooth_buf[i-2] - 0.5769*m_smooth_buf[i-4] - 0.0962*m_smooth_buf[i-6]) * (0.075*period_prev + 0.54);

      // 3. InPhase and Quadrature
      m_Q1_buf[i] = (0.0962*m_detrender_buf[i] + 0.5769*m_detrender_buf[i-2] - 0.5769*m_detrender_buf[i-4] - 0.0962*m_detrender_buf[i-6]) * (0.075*period_prev + 0.54);
      m_I1_buf[i] = m_detrender_buf[i-3];

      // 4. Phase advance
      m_jI_buf[i] = (0.0962*m_I1_buf[i] + 0.5769*m_I1_buf[i-2] - 0.5769*m_I1_buf[i-4] - 0.0962*m_I1_buf[i-6]) * (0.075*period_prev + 0.54);
      m_jQ_buf[i] = (0.0962*m_Q1_buf[i] + 0.5769*m_Q1_buf[i-2] - 0.5769*m_Q1_buf[i-4] - 0.0962*m_Q1_buf[i-6]) * (0.075*period_prev + 0.54);

      // 5. Phasor addition
      double I2 = m_I1_buf[i] - m_jQ_buf[i];
      double Q2 = m_Q1_buf[i] + m_jI_buf[i];

      m_I2_buf[i] = 0.2*I2 + 0.8*m_I2_buf[i-1];
      m_Q2_buf[i] = 0.2*Q2 + 0.8*m_Q2_buf[i-1];

      // 6. Homodyne Discriminator
      double Re = m_I2_buf[i]*m_I2_buf[i-1] + m_Q2_buf[i]*m_Q2_buf[i-1];
      double Im = m_I2_buf[i]*m_Q2_buf[i-1] - m_Q2_buf[i]*m_I2_buf[i-1];

      m_Re_buf[i] = 0.2*Re + 0.8*m_Re_buf[i-1];
      m_Im_buf[i] = 0.2*Im + 0.8*m_Im_buf[i-1];

      // 7. Cycle Period
      double period = 0;
      if(m_Im_buf[i]!=0.0 && m_Re_buf[i]!=0.0)
         period = 360.0 / (atan(m_Im_buf[i]/m_Re_buf[i]) * 180.0/M_PI);

      if(period > 1.5*m_period_buf[i-1])
         period = 1.5*m_period_buf[i-1];
      if(period < 0.67*m_period_buf[i-1])
         period = 0.67*m_period_buf[i-1];
      if(period < 6)
         period = 6;
      if(period > 50)
         period = 50;

      m_period_buf[i] = 0.2*period + 0.8*m_period_buf[i-1];
      m_smooth_period_buf[i] = 0.33*m_period_buf[i] + 0.67*m_smooth_period_buf[i-1];

      // 8. Delta Phase
      double phase = 0;
      if(m_I1_buf[i] != 0.0)
         phase = atan(m_Q1_buf[i]/m_I1_buf[i]) * 180.0/M_PI;

      double delta_phase = m_phase_buf[i-1] - phase;
      if(delta_phase < 1.0)
         delta_phase = 1.0;
      m_phase_buf[i] = phase;

      // 9. Adaptive Alpha
      double alpha = m_fast_limit / delta_phase;
      if(alpha < m_slow_limit)
         alpha = m_slow_limit;

      // 10. MAMA and FAMA
      m_mama_buf[i] = alpha * m_price[i] + (1.0 - alpha) * m_mama_buf[i-1];
      m_fama_buf[i] = 0.5 * alpha * m_mama_buf[i] + (1.0 - 0.5 * alpha) * m_fama_buf[i-1];

      mama_buffer[i] = m_mama_buf[i];
      fama_buffer[i] = m_fama_buf[i];
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CMAMACalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|             CLASS 2: CMAMACalculator_HA (Heikin Ashi)            |
//+==================================================================+
class CMAMACalculator_HA : public CMAMACalculator
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
bool CMAMACalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
