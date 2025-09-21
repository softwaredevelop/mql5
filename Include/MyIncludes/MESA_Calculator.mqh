//+------------------------------------------------------------------+
//|                                            MESA_Calculator.mqh   |
//|      Calculation engine for Ehlers' MAMA/FAMA.                   |
//|           (Based on the official MotiveWave pseudo-code)         |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CMESACalculator
  {
private:
   double            m_fast_limit;
   double            m_slow_limit;
#define DECLARE_BUFFER(name) double m_##name[]
                     DECLARE_BUFFER(smooth);
                     DECLARE_BUFFER(detrender);
                     DECLARE_BUFFER(i1);
                     DECLARE_BUFFER(q1);
                     DECLARE_BUFFER(jI);
                     DECLARE_BUFFER(jQ);
                     DECLARE_BUFFER(i2);
                     DECLARE_BUFFER(q2);
                     DECLARE_BUFFER(re);
                     DECLARE_BUFFER(im);
                     DECLARE_BUFFER(period);
                     DECLARE_BUFFER(smooth_period);
                     DECLARE_BUFFER(phase);
                     DECLARE_BUFFER(alpha);
                     DECLARE_BUFFER(mama);
                     DECLARE_BUFFER(fama);
#undef DECLARE_BUFFER
public:
                     CMESACalculator(void) : m_fast_limit(0.5), m_slow_limit(0.05) {}
                    ~CMESACalculator(void) {}
   bool              Init(double fast_limit, double slow_limit) { m_fast_limit = fast_limit; m_slow_limit = slow_limit; return true; }
   void              Calculate(int rates_total, const double &price_src[], double &mama_out[], double &fama_out[])
     {
      int warmup_period = 10;
      if(rates_total < warmup_period)
         return;

#define RESIZE_BUFFER(name) ArrayResize(m_##name, rates_total, 0)
      RESIZE_BUFFER(smooth);
      RESIZE_BUFFER(detrender);
      RESIZE_BUFFER(i1);
      RESIZE_BUFFER(q1);
      RESIZE_BUFFER(jI);
      RESIZE_BUFFER(jQ);
      RESIZE_BUFFER(i2);
      RESIZE_BUFFER(q2);
      RESIZE_BUFFER(re);
      RESIZE_BUFFER(im);
      RESIZE_BUFFER(period);
      RESIZE_BUFFER(smooth_period);
      RESIZE_BUFFER(phase);
      RESIZE_BUFFER(alpha);
      RESIZE_BUFFER(mama);
      RESIZE_BUFFER(fama);
#undef RESIZE_BUFFER

#define nz(arr, idx) ( (i >= idx) ? arr[i-idx] : 0 )

      for(int i = 0; i < rates_total; i++)
        {
         if(i < warmup_period)
           {
            m_mama[i] = price_src[i];
            m_fama[i] = price_src[i];
            m_period[i] = 20;
            m_smooth_period[i] = 20;
            continue;
           }

         //--- Calculations exactly as per MotiveWave pseudo-code ---
         m_smooth[i] = (4 * price_src[i] + 3 * nz(price_src,1) + 2 * nz(price_src,2) + nz(price_src,3)) / 10.0;

         m_detrender[i] = (0.0962 * m_smooth[i] + 0.5769 * nz(m_smooth,2) - 0.5769 * nz(m_smooth,4) - 0.0962 * nz(m_smooth,6)) * (0.075 * nz(m_period,1) + 0.54);

         m_q1[i] = (0.0962 * m_detrender[i] + 0.5769 * nz(m_detrender,2) - 0.5769 * nz(m_detrender,4) - 0.0962 * nz(m_detrender,6)) * (0.075 * nz(m_period,1) + 0.54);
         m_i1[i] = nz(m_detrender,3);

         m_jI[i] = (0.0962 * m_i1[i] + 0.5769 * nz(m_i1,2) - 0.5769 * nz(m_i1,4) - 0.0962 * nz(m_i1,6)) * (0.075 * nz(m_period,1) + 0.54);
         m_jQ[i] = (0.0962 * m_q1[i] + 0.5769 * nz(m_q1,2) - 0.5769 * nz(m_q1,4) - 0.0962 * nz(m_q1,6)) * (0.075 * nz(m_period,1) + 0.54);

         m_i2[i] = m_i1[i] - m_jQ[i];
         m_q2[i] = m_q1[i] + m_jI[i];

         m_i2[i] = 0.2 * m_i2[i] + 0.8 * nz(m_i2,1);
         m_q2[i] = 0.2 * m_q2[i] + 0.8 * nz(m_q2,1);

         m_re[i] = m_i2[i] * nz(m_i2,1) + m_q2[i] * nz(m_q2,1);
         m_im[i] = m_i2[i] * nz(m_q2,1) - m_q2[i] * nz(m_i2,1);

         m_re[i] = 0.2 * m_re[i] + 0.8 * nz(m_re,1);
         m_im[i] = 0.2 * m_im[i] + 0.8 * nz(m_im,1);

         if(m_im[i] != 0.0 && m_re[i] != 0.0)
            m_period[i] = 360.0 / (MathArctan(m_im[i] / m_re[i]) * 180.0 / M_PI);
         else
            m_period[i] = nz(m_period,1);

         if(m_period[i] > 1.5 * nz(m_period,1))
            m_period[i] = 1.5 * nz(m_period,1);
         if(m_period[i] < 0.67 * nz(m_period,1))
            m_period[i] = 0.67 * nz(m_period,1);
         if(m_period[i] < 6)
            m_period[i] = 6;
         if(m_period[i] > 50)
            m_period[i] = 50;

         m_period[i] = 0.2 * m_period[i] + 0.8 * nz(m_period,1);
         m_smooth_period[i] = 0.33 * m_period[i] + 0.67 * nz(m_smooth_period,1);

         if(m_i1[i] != 0.0)
            m_phase[i] = (MathArctan(m_q1[i] / m_i1[i]) * 180.0 / M_PI);
         else
            m_phase[i] = nz(m_phase,1);

         double delta_phase = nz(m_phase,1) - m_phase[i];
         if(delta_phase < 1.0)
            delta_phase = 1.0;

         m_alpha[i] = m_fast_limit / delta_phase;
         if(m_alpha[i] < m_slow_limit)
            m_alpha[i] = m_slow_limit;
         if(m_alpha[i] > m_fast_limit)
            m_alpha[i] = m_fast_limit;

         m_mama[i] = m_alpha[i] * price_src[i] + (1 - m_alpha[i]) * nz(m_mama,1);
         m_fama[i] = 0.5 * m_alpha[i] * m_mama[i] + (1 - 0.5 * m_alpha[i]) * nz(m_fama,1);
        }

#undef nz

      ArrayCopy(mama_out, m_mama, 0, 0, rates_total);
      ArrayCopy(fama_out, m_fama, 0, 0, rates_total);
     }
  };
//+------------------------------------------------------------------+
