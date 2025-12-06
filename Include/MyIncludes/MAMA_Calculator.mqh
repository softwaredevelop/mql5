//+------------------------------------------------------------------+
//|                                              MAMA_Calculator.mqh |
//|      VERSION 1.20: Reverted to Full Recalc for consistency.      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
class CMAMACalculator
  {
protected:
   double            m_fast_limit;
   double            m_slow_limit;

   //--- Buffers
   double            m_price[];
   // We keep internal buffers as members to avoid reallocation,
   // but we will overwrite them every time.
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

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CMAMACalculator(void) {};
   virtual          ~CMAMACalculator(void) {};

   bool              Init(double fast_limit, double slow_limit);

   //--- Reverted: No prev_calculated needed
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &mama_buffer[], double &fama_buffer[]);
  };

//+------------------------------------------------------------------+
bool CMAMACalculator::Init(double fast_limit, double slow_limit)
  {
   m_fast_limit = fast_limit;
   m_slow_limit = slow_limit;
   return true;
  }

//+------------------------------------------------------------------+
void CMAMACalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                double &mama_buffer[], double &fama_buffer[])
  {
   if(rates_total < 50)
      return;

//--- Always Full Recalculation

//--- Resize Internal Buffers
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

// Initialize buffers with 0 (important for full recalc)
   ArrayInitialize(m_smooth_buf, 0);
   ArrayInitialize(m_detrender_buf, 0);
   ArrayInitialize(m_I1_buf, 0);
   ArrayInitialize(m_Q1_buf, 0);
   ArrayInitialize(m_jI_buf, 0);
   ArrayInitialize(m_jQ_buf, 0);
   ArrayInitialize(m_I2_buf, 0);
   ArrayInitialize(m_Q2_buf, 0);
   ArrayInitialize(m_Re_buf, 0);
   ArrayInitialize(m_Im_buf, 0);
   ArrayInitialize(m_period_buf, 0);
   ArrayInitialize(m_smooth_period_buf, 0);
   ArrayInitialize(m_phase_buf, 0);
// MAMA/FAMA init with price later

   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

//--- Main Loop (From 0 to Total)
   for(int i = 0; i < rates_total; i++)
     {
      // Initialization for first few bars
      if(i < 7)
        {
         m_mama_buf[i] = m_price[i];
         m_fama_buf[i] = m_price[i];
         mama_buffer[i] = m_price[i];
         fama_buffer[i] = m_price[i];
         continue;
        }

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
bool CMAMACalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Full copy
   for(int i = 0; i < rates_total; i++)
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
class CMAMACalculator_HA : public CMAMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CMAMACalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

// Full Recalc for HA
   m_ha_calculator.Calculate(rates_total, 0, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   for(int i = 0; i < rates_total; i++)
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
