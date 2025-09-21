//+------------------------------------------------------------------+
//|                                            MESA_Calculator.mqh   |
//|      Calculation engines for Standard and Heikin Ashi MAMA/FAMA. |
//|           (Based on the official MotiveWave pseudo-code)         |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CMESACalculator (Standard)                  |
//|                                                                  |
//+==================================================================+
class CMESACalculator
  {
protected:
   double            m_fast_limit;
   double            m_slow_limit;

#define DECLARE_BUFFER(name) double m_##name[]
                     DECLARE_BUFFER(price);
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

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CMESACalculator(void);
   virtual          ~CMESACalculator(void) {};

   bool              Init(double fast_limit, double slow_limit);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &mama_out[], double &fama_out[]);
  };

//+------------------------------------------------------------------+
//| CMESACalculator: Constructor                                     |
//+------------------------------------------------------------------+
CMESACalculator::CMESACalculator(void) : m_fast_limit(0.5), m_slow_limit(0.05)
  {
  }

//+------------------------------------------------------------------+
//| CMESACalculator: Initialization                                  |
//+------------------------------------------------------------------+
bool CMESACalculator::Init(double fast_limit, double slow_limit)
  {
   m_fast_limit = fast_limit;
   m_slow_limit = slow_limit;
   return true;
  }

//+------------------------------------------------------------------+
//| CMESACalculator: Main Calculation Method                         |
//+------------------------------------------------------------------+
void CMESACalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &mama_out[], double &fama_out[])
  {
   int warmup_period = 10;
   if(rates_total < warmup_period)
      return;

#define RESIZE_BUFFER(name) ArrayResize(m_##name, rates_total, 0)
   RESIZE_BUFFER(price);
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

   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

#define nz(arr, idx) ( (i >= idx) ? arr[i-idx] : 0 )

   for(int i = 0; i < rates_total; i++)
     {
      if(i < warmup_period)
        {
         m_mama[i] = m_price[i];
         m_fama[i] = m_price[i];
         m_period[i] = 20;
         m_smooth_period[i] = 20;
         continue;
        }

      m_smooth[i] = (4 * m_price[i] + 3 * nz(m_price,1) + 2 * nz(m_price,2) + nz(m_price,3)) / 10.0;
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
      m_mama[i] = m_alpha[i] * m_price[i] + (1 - m_alpha[i]) * nz(m_mama,1);
      m_fama[i] = 0.5 * m_alpha[i] * m_mama[i] + (1 - 0.5 * m_alpha[i]) * nz(m_fama,1);
     }

#undef nz

   ArrayCopy(mama_out, m_mama, 0, 0, rates_total);
   ArrayCopy(fama_out, m_fama, 0, 0, rates_total);
  }

//+------------------------------------------------------------------+
//| CMESACalculator: Prepares the source price series.               |
//+------------------------------------------------------------------+
bool CMESACalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
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
//|                                                                  |
//|             CLASS 2: CMESACalculator_HA (Heikin Ashi)            |
//|                                                                  |
//+==================================================================+
class CMESACalculator_HA : public CMESACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;

protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
  };

//+------------------------------------------------------------------+
//| CMESACalculator_HA: Prepares the source price series.            |
//+------------------------------------------------------------------+
bool CMESACalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- The HA version ALWAYS uses the HA Close price, ignoring the price_type input
   ArrayCopy(m_price, ha_close, 0, 0, rates_total);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
