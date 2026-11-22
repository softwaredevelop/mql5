//+------------------------------------------------------------------+
//|                                              MAMA_Calculator.mqh |
//|      DSP Engine for John Ehlers' MESA Adaptive Moving Average    |
//|      VERSION 2.00: 2026 Enterprise Edition with Trigonometric    |
//|                    Epsilon Shield & 16-Buffer Capacity Memory    |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.00"

#ifndef MAMA_CALCULATOR_MQH
#define MAMA_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

#define RAD_TO_DEG 57.295779513082320876798154814105

//+==================================================================+
//|             CLASS 1: CMAMACalculator (Base Class)                |
//+==================================================================+
class CMAMACalculator
  {
protected:
   double            m_fast_limit;
   double            m_slow_limit;

   //--- Persistent State Buffers for Incremental Calculation
   double            m_price[];

   //--- Internal 16 DSP State Buffers
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

   virtual bool      PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
                                        const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CMAMACalculator(void);
   virtual          ~CMAMACalculator(void) {}

   bool              Init(const double fast_limit, const double slow_limit);

   void              Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &mama_buffer[], double &fama_buffer[]);

   double            GetFastLimit(void)  const { return m_fast_limit; }
   double            GetSlowLimit(void)  const { return m_slow_limit; }
   int               GetWarmupBars(void) const { return 50; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMAMACalculator::CMAMACalculator(void) : m_fast_limit(0.5), m_slow_limit(0.05)
  {
   ArraySetAsSeries(m_price,             false);
   ArraySetAsSeries(m_smooth_buf,        false);
   ArraySetAsSeries(m_detrender_buf,     false);
   ArraySetAsSeries(m_I1_buf,            false);
   ArraySetAsSeries(m_Q1_buf,            false);
   ArraySetAsSeries(m_jI_buf,            false);
   ArraySetAsSeries(m_jQ_buf,            false);
   ArraySetAsSeries(m_I2_buf,            false);
   ArraySetAsSeries(m_Q2_buf,            false);
   ArraySetAsSeries(m_Re_buf,            false);
   ArraySetAsSeries(m_Im_buf,            false);
   ArraySetAsSeries(m_period_buf,        false);
   ArraySetAsSeries(m_smooth_period_buf, false);
   ArraySetAsSeries(m_phase_buf,         false);
   ArraySetAsSeries(m_mama_buf,          false);
   ArraySetAsSeries(m_fama_buf,          false);
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMAMACalculator::Init(const double fast_limit, const double slow_limit)
  {
   m_fast_limit = (fast_limit <= 0.0) ? 0.5  : fast_limit;
   m_slow_limit = (slow_limit <= 0.0) ? 0.05 : slow_limit;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Numerically Shielded Incremental DSP)          |
//+------------------------------------------------------------------+
void CMAMACalculator::Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                const double &open[], const double &high[], const double &low[], const double &close[],
                                double &mama_buffer[], double &fama_buffer[])
  {
   if(rates_total < 50)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize all 16 internal buffers with memory reservation capacity
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price,             rates_total, 2048);
      ArrayResize(m_smooth_buf,        rates_total, 2048);
      ArrayResize(m_detrender_buf,     rates_total, 2048);
      ArrayResize(m_I1_buf,            rates_total, 2048);
      ArrayResize(m_Q1_buf,            rates_total, 2048);
      ArrayResize(m_jI_buf,            rates_total, 2048);
      ArrayResize(m_jQ_buf,            rates_total, 2048);
      ArrayResize(m_I2_buf,            rates_total, 2048);
      ArrayResize(m_Q2_buf,            rates_total, 2048);
      ArrayResize(m_Re_buf,            rates_total, 2048);
      ArrayResize(m_Im_buf,            rates_total, 2048);
      ArrayResize(m_period_buf,        rates_total, 2048);
      ArrayResize(m_smooth_period_buf, rates_total, 2048);
      ArrayResize(m_phase_buf,         rates_total, 2048);
      ArrayResize(m_mama_buf,          rates_total, 2048);
      ArrayResize(m_fama_buf,          rates_total, 2048);

      ArraySetAsSeries(m_price,             false);
      ArraySetAsSeries(m_smooth_buf,        false);
      ArraySetAsSeries(m_detrender_buf,     false);
      ArraySetAsSeries(m_I1_buf,            false);
      ArraySetAsSeries(m_Q1_buf,            false);
      ArraySetAsSeries(m_jI_buf,            false);
      ArraySetAsSeries(m_jQ_buf,            false);
      ArraySetAsSeries(m_I2_buf,            false);
      ArraySetAsSeries(m_Q2_buf,            false);
      ArraySetAsSeries(m_Re_buf,            false);
      ArraySetAsSeries(m_Im_buf,            false);
      ArraySetAsSeries(m_period_buf,        false);
      ArraySetAsSeries(m_smooth_period_buf, false);
      ArraySetAsSeries(m_phase_buf,         false);
      ArraySetAsSeries(m_mama_buf,          false);
      ArraySetAsSeries(m_fama_buf,          false);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   int i = start_index;

// Deterministic Seeding for bars 0 ... 6
   if(i < 7)
     {
      for(int k = 0; k < 7; k++)
        {
         if(k >= rates_total)
            break;
         m_smooth_buf[k]        = 0.0;
         m_detrender_buf[k]     = 0.0;
         m_I1_buf[k]            = 0.0;
         m_Q1_buf[k]            = 0.0;
         m_jI_buf[k]            = 0.0;
         m_jQ_buf[k]            = 0.0;
         m_I2_buf[k]            = 0.0;
         m_Q2_buf[k]            = 0.0;
         m_Re_buf[k]            = 0.0;
         m_Im_buf[k]            = 0.0;
         m_period_buf[k]        = 12.0;
         m_smooth_period_buf[k] = 12.0;
         m_phase_buf[k]         = 0.0;
         m_mama_buf[k]          = m_price[k];
         m_fama_buf[k]          = m_price[k];
         mama_buffer[k]         = m_price[k];
         fama_buffer[k]         = m_price[k];
        }
      i = 7;
     }

   for(; i < rates_total; i++)
     {
      // 1. 4-bar WMA Smoothing
      m_smooth_buf[i] = (4.0 * m_price[i] + 3.0 * m_price[i - 1] + 2.0 * m_price[i - 2] + m_price[i - 3]) * 0.1;

      // 2. Hilbert Transform Detrender
      double period_prev = m_period_buf[i - 1];
      double hilbert_gain = 0.075 * period_prev + 0.54;

      m_detrender_buf[i] = (0.0962 * m_smooth_buf[i] + 0.5769 * m_smooth_buf[i - 2] - 0.5769 * m_smooth_buf[i - 4] - 0.0962 * m_smooth_buf[i - 6]) * hilbert_gain;

      // 3. InPhase and Quadrature Components
      m_Q1_buf[i] = (0.0962 * m_detrender_buf[i] + 0.5769 * m_detrender_buf[i - 2] - 0.5769 * m_detrender_buf[i - 4] - 0.0962 * m_detrender_buf[i - 6]) * hilbert_gain;
      m_I1_buf[i] = m_detrender_buf[i - 3];

      // 4. Phase Advance
      m_jI_buf[i] = (0.0962 * m_I1_buf[i] + 0.5769 * m_I1_buf[i - 2] - 0.5769 * m_I1_buf[i - 4] - 0.0962 * m_I1_buf[i - 6]) * hilbert_gain;
      m_jQ_buf[i] = (0.0962 * m_Q1_buf[i] + 0.5769 * m_Q1_buf[i - 2] - 0.5769 * m_Q1_buf[i - 4] - 0.0962 * m_Q1_buf[i - 6]) * hilbert_gain;

      // 5. Phasor Addition & Smoothing
      double I2 = m_I1_buf[i] - m_jQ_buf[i];
      double Q2 = m_Q1_buf[i] + m_jI_buf[i];

      m_I2_buf[i] = 0.2 * I2 + 0.8 * m_I2_buf[i - 1];
      m_Q2_buf[i] = 0.2 * Q2 + 0.8 * m_Q2_buf[i - 1];

      // 6. Homodyne Discriminator
      double Re = m_I2_buf[i] * m_I2_buf[i - 1] + m_Q2_buf[i] * m_Q2_buf[i - 1];
      double Im = m_I2_buf[i] * m_Q2_buf[i - 1] - m_Q2_buf[i] * m_I2_buf[i - 1];

      m_Re_buf[i] = 0.2 * Re + 0.8 * m_Re_buf[i - 1];
      m_Im_buf[i] = 0.2 * Im + 0.8 * m_Im_buf[i - 1];

      // 7. Cycle Period with Trigonometric Epsilon Guard
      double period = period_prev;
      if(m_Im_buf[i] != 0.0 && m_Re_buf[i] != 0.0)
        {
         double rad = atan(m_Im_buf[i] / m_Re_buf[i]);
         double deg = rad * RAD_TO_DEG;
         if(MathAbs(deg) > 1.0e-5)
            period = 360.0 / deg;
        }

      // Constrain cycle rate-of-change
      if(period > 1.5 * period_prev)
         period = 1.5 * period_prev;
      if(period < 0.67 * period_prev)
         period = 0.67 * period_prev;
      if(period < 6.0)
         period = 6.0;
      if(period > 50.0)
         period = 50.0;

      m_period_buf[i]        = 0.2 * period + 0.8 * period_prev;
      m_smooth_period_buf[i] = 0.33 * m_period_buf[i] + 0.67 * m_smooth_period_buf[i - 1];

      // 8. Phase Angle Derivation
      double phase = m_phase_buf[i - 1];
      if(m_I1_buf[i] != 0.0)
         phase = atan(m_Q1_buf[i] / m_I1_buf[i]) * RAD_TO_DEG;

      double delta_phase = m_phase_buf[i - 1] - phase;
      if(delta_phase < 1.0)
         delta_phase = 1.0;

      m_phase_buf[i] = phase;

      // 9. Adaptive Alpha with Upper and Lower Clamps
      double alpha = m_fast_limit / delta_phase;
      if(alpha < m_slow_limit)
         alpha = m_slow_limit;
      if(alpha > m_fast_limit)
         alpha = m_fast_limit;

      // 10. MAMA and FAMA Non-linear Filtering
      m_mama_buf[i] = alpha * m_price[i] + (1.0 - alpha) * m_mama_buf[i - 1];
      m_fama_buf[i] = 0.5 * alpha * m_mama_buf[i] + (1.0 - 0.5 * alpha) * m_fama_buf[i - 1];

      mama_buffer[i] = m_mama_buf[i];
      fama_buffer[i] = m_fama_buf[i];
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - ALU Optimized)                         |
//+------------------------------------------------------------------+
bool CMAMACalculator::PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (high[i] + low[i]) * 0.5;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i] + low[i] + close[i]) * 0.3333333333333333;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i] + low[i] + 2.0 * close[i]) * 0.25;
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
   double                 m_ha_open[]; // Only HA open requires persistent recursive state
   double                 m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool           PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
         const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - ALU Optimized)                      |
//+------------------------------------------------------------------+
bool CMAMACalculator_HA::PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open,  rates_total, 2048);
      ArrayResize(m_ha_high,  rates_total, 2048);
      ArrayResize(m_ha_low,   rates_total, 2048);
      ArrayResize(m_ha_close, rates_total, 2048);

      ArraySetAsSeries(m_ha_open,  false);
      ArraySetAsSeries(m_ha_high,  false);
      ArraySetAsSeries(m_ha_low,   false);
      ArraySetAsSeries(m_ha_close, false);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

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
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) * 0.5;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) * 0.3333333333333333;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) * 0.25;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }

#endif // MAMA_CALCULATOR_MQH
//+------------------------------------------------------------------+
