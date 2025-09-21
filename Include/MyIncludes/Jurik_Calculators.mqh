//+------------------------------------------------------------------+
//|                                         Jurik_Calculators.mqh    |
//|      Calculation engines for standard and Heikin Ashi Jurik      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CJurikMACalculator (Standard)               |
//|                                                                  |
//+==================================================================+
class CJurikMACalculator
  {
protected: // Changed to protected to allow inheritance if needed in future
   //--- Parameters
   int               m_length;
   double            m_phase;
   int               m_price_type;

   //--- Internal calculation buffers
   double            m_price[];
   double            m_kv;
   double            m_pow2;
   double            m_upper_band[];
   double            m_lower_band[];
   double            m_volty[];
   double            m_avg_volty[];
   double            m_rvolty[];
   double            m_beta;
   double            m_alpha[];
   double            m_phase_ratio[];
   double            m_ma1[];
   double            m_det0[];
   double            m_ma2[];
   double            m_det1[];
   double            m_jma[];

   //--- Helper methods
   virtual void      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CJurikMACalculator(void);
   virtual          ~CJurikMACalculator(void) {}; // Made virtual for safe inheritance

   virtual bool      Init(int length, double phase, int price_type);
   virtual void      Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &jma_out[], double &upper_band_out[], double &lower_band_out[], double &volty_out[]);
  };

//+------------------------------------------------------------------+
//| CJurikMACalculator: Constructor                                  |
//+------------------------------------------------------------------+
CJurikMACalculator::CJurikMACalculator(void) : m_length(0), m_phase(0), m_price_type(0)
  {
  }

//+------------------------------------------------------------------+
//| CJurikMACalculator: Initialization                               |
//+------------------------------------------------------------------+
bool CJurikMACalculator::Init(int length, double phase, int price_type)
  {
   m_length = (length < 1) ? 1 : length;
   m_phase = phase;
   m_price_type = price_type;

   m_beta = 0.45 * (m_length - 1) / (0.45 * (m_length - 1) + 2);

   double len1 = MathLog(MathSqrt(m_length)) / MathLog(2.0) + 2.0;
   m_pow2 = (len1 > 2) ? len1 - 2 : 0.5;
   if(m_pow2 < 0.5)
      m_pow2 = 0.5;

   m_kv = MathPow(m_beta, MathSqrt(m_pow2));

   return true;
  }

//+------------------------------------------------------------------+
//| CJurikMACalculator: Main Calculation Method                      |
//+------------------------------------------------------------------+
void CJurikMACalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                                   double &jma_out[], double &upper_band_out[], double &lower_band_out[], double &volty_out[])
  {
   if(rates_total < m_length)
      return;

#define RESIZE_ARRAY(arr) ArrayResize(arr, rates_total)
   RESIZE_ARRAY(m_price);
   RESIZE_ARRAY(m_upper_band);
   RESIZE_ARRAY(m_lower_band);
   RESIZE_ARRAY(m_volty);
   RESIZE_ARRAY(m_avg_volty);
   RESIZE_ARRAY(m_rvolty);
   RESIZE_ARRAY(m_alpha);
   RESIZE_ARRAY(m_phase_ratio);
   RESIZE_ARRAY(m_ma1);
   RESIZE_ARRAY(m_det0);
   RESIZE_ARRAY(m_ma2);
   RESIZE_ARRAY(m_det1);
   RESIZE_ARRAY(m_jma);
#undef RESIZE_ARRAY

   PreparePriceSeries(rates_total, open, high, low, close);

   m_upper_band[0] = m_price[0];
   m_lower_band[0] = m_price[0];
   m_volty[0] = 0;
   for(int i = 1; i < rates_total; i++)
     {
      double del1 = m_price[i] - m_upper_band[i-1];
      double del2 = m_price[i] - m_lower_band[i-1];
      if(del1 > 0)
         m_upper_band[i] = m_price[i];
      else
         m_upper_band[i] = m_price[i] - m_kv * del1;
      if(del2 < 0)
         m_lower_band[i] = m_price[i];
      else
         m_lower_band[i] = m_price[i] - m_kv * del2;
      m_volty[i] = (MathAbs(del1) == MathAbs(del2)) ? 0 : MathMax(MathAbs(del1), MathAbs(del2));
     }

   double len1 = MathLog(MathSqrt(m_length)) / MathLog(2.0) + 2.0;
   double pow1 = (len1 > 2) ? len1 - 2 : 0.5;
   if(pow1 < 0.5)
      pow1 = 0.5;

   double volty_sum = 0;
   for(int i = 1; i < rates_total; i++)
     {
      volty_sum += m_volty[i];
      if(i > m_length)
         volty_sum -= m_volty[i - m_length];
      if(i >= m_length)
         m_avg_volty[i] = volty_sum / m_length;
      else
         m_avg_volty[i] = 0;

      if(m_avg_volty[i] > 0)
         m_rvolty[i] = m_volty[i] / m_avg_volty[i];
      else
         m_rvolty[i] = 0;
      if(m_rvolty[i] < 1)
         m_rvolty[i] = 1;

      double pow_val = MathPow(m_rvolty[i], pow1);
      m_alpha[i] = MathPow(m_beta, pow_val);
     }

   double pr_phase = m_phase / 100.0 + 1.5;
   if(m_phase < -100)
      pr_phase = 0.5;
   if(m_phase > 100)
      pr_phase = 2.5;

   m_ma1[0] = m_price[0];
   m_det0[0] = 0;
   m_ma2[0] = m_price[0];
   m_det1[0] = 0;
   m_jma[0] = m_price[0];

   for(int i = 1; i < rates_total; i++)
     {
      m_ma1[i] = (1 - m_alpha[i]) * m_price[i] + m_alpha[i] * m_ma1[i-1];
      m_det0[i] = (m_price[i] - m_ma1[i]) * (1 - m_beta) + m_beta * m_det0[i-1];
      m_ma2[i] = m_ma1[i] + pr_phase * m_det0[i];
      m_det1[i] = (m_ma2[i] - m_jma[i-1]) * MathPow(1 - m_alpha[i], 2) + MathPow(m_alpha[i], 2) * m_det1[i-1];
      m_jma[i] = m_jma[i-1] + m_det1[i];
     }

   ArrayCopy(jma_out, m_jma, 0, 0, rates_total);
   ArrayCopy(upper_band_out, m_upper_band, 0, 0, rates_total);
   ArrayCopy(lower_band_out, m_lower_band, 0, 0, rates_total);
   ArrayCopy(volty_out, m_volty, 0, 0, rates_total);
  }

//+------------------------------------------------------------------+
//| CJurikMACalculator: Prepares the source price series.            |
//+------------------------------------------------------------------+
void CJurikMACalculator::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayCopy(m_price, close, 0, 0, rates_total);
  }

//+==================================================================+
//|                                                                  |
//|             CLASS 2: CJurikMACalculator_HA (Heikin Ashi)         |
//|                                                                  |
//+==================================================================+
class CJurikMACalculator_HA : public CJurikMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;

protected:
   virtual void      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);
  };

//+------------------------------------------------------------------+
//| CJurikMACalculator_HA: Prepares the source price series.         |
//+------------------------------------------------------------------+
void CJurikMACalculator_HA::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
//--- Step 1: Calculate Heikin Ashi data from the original OHLC
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- Step 2: Use the HA Close as the source price for all further calculations
   ArrayCopy(m_price, ha_close, 0, 0, rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
