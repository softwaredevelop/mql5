//+------------------------------------------------------------------+
//|                                         MAMA_FAMA_Calculator.mqh |
//|      Calculation engine for Standard and Heikin Ashi MAMA/FAMA.  |
//|           (Based on the official MotiveWave pseudo-code)         |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CMAMACalculator (Base Class)                |
//|                                                                  |
//+==================================================================+
class CMAMACalculator
  {
protected:
   double            m_fast_limit;
   double            m_slow_limit;

   //--- Internal buffers for state-dependent calculation
   double            m_price[];
   double            m_smooth[];
   double            m_detrender[];
   double            m_i1[];
   double            m_q1[];
   double            m_jI[];
   double            m_jQ[];
   double            m_i2[];
   double            m_q2[];
   double            m_re[];
   double            m_im[];
   double            m_period[];
   double            m_smooth_period[];
   double            m_phase[];
   double            m_alpha[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CMAMACalculator(void);
   virtual          ~CMAMACalculator(void) {};

   bool              Init(double fast_limit, double slow_limit);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &mama_out[], double &fama_out[]);
  };

//+------------------------------------------------------------------+
//| CMAMACalculator: Constructor                                     |
//+------------------------------------------------------------------+
CMAMACalculator::CMAMACalculator(void) : m_fast_limit(0.5), m_slow_limit(0.05)
  {
  }

//+------------------------------------------------------------------+
//| CMAMACalculator: Initialization                                  |
//+------------------------------------------------------------------+
bool CMAMACalculator::Init(double fast_limit, double slow_limit)
  {
   m_fast_limit = fast_limit;
   m_slow_limit = slow_limit;
   return true;
  }

//+------------------------------------------------------------------+
//| CMAMACalculator: Main Calculation Method                         |
//+------------------------------------------------------------------+
void CMAMACalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &mama_out[], double &fama_out[])
  {
   int warmup_period = 10;
   if(rates_total < warmup_period)
      return;

//--- Resize all internal buffers
   ArrayResize(m_price, rates_total);
   ArrayResize(m_smooth, rates_total);
   ArrayResize(m_detrender, rates_total);
   ArrayResize(m_i1, rates_total);
   ArrayResize(m_q1, rates_total);
   ArrayResize(m_jI, rates_total);
   ArrayResize(m_jQ, rates_total);
   ArrayResize(m_i2, rates_total);
   ArrayResize(m_q2, rates_total);
   ArrayResize(m_re, rates_total);
   ArrayResize(m_im, rates_total);
   ArrayResize(m_period, rates_total);
   ArrayResize(m_smooth_period, rates_total);
   ArrayResize(m_phase, rates_total);
   ArrayResize(m_alpha, rates_total);

   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   for(int i = 0; i < rates_total; i++)
     {
      if(i < warmup_period)
        {
         mama_out[i] = m_price[i];
         fama_out[i] = m_price[i];
         m_period[i] = 20;
         m_smooth_period[i] = 20;
         continue;
        }

      double prev_period = (i > 0) ? m_period[i-1] : 20;
      double prev_smooth_period = (i > 0) ? m_smooth_period[i-1] : 20;
      double prev_phase = (i > 0) ? m_phase[i-1] : 0;
      double prev_i2 = (i > 0) ? m_i2[i-1] : 0;
      double prev_q2 = (i > 0) ? m_q2[i-1] : 0;
      double prev_re = (i > 0) ? m_re[i-1] : 0;
      double prev_im = (i > 0) ? m_im[i-1] : 0;
      double prev_mama = (i > 0) ? mama_out[i-1] : m_price[i];
      double prev_fama = (i > 0) ? fama_out[i-1] : m_price[i];

      m_smooth[i] = (4*m_price[i] + 3*m_price[i-1] + 2*m_price[i-2] + m_price[i-3]) / 10.0;
      m_detrender[i] = (0.0962*m_smooth[i] + 0.5769*m_smooth[i-2] - 0.5769*m_smooth[i-4] - 0.0962*m_smooth[i-6]) * (0.075*prev_period + 0.54);
      m_q1[i] = (0.0962*m_detrender[i] + 0.5769*m_detrender[i-2] - 0.5769*m_detrender[i-4] - 0.0962*m_detrender[i-6]) * (0.075*prev_period + 0.54);
      m_i1[i] = m_detrender[i-3];
      m_jI[i] = (0.0962*m_i1[i] + 0.5769*m_i1[i-2] - 0.5769*m_i1[i-4] - 0.0962*m_i1[i-6]) * (0.075*prev_period + 0.54);
      m_jQ[i] = (0.0962*m_q1[i] + 0.5769*m_q1[i-2] - 0.5769*m_q1[i-4] - 0.0962*m_q1[i-6]) * (0.075*prev_period + 0.54);
      m_i2[i] = m_i1[i] - m_jQ[i];
      m_q2[i] = m_q1[i] + m_jI[i];
      m_i2[i] = 0.2*m_i2[i] + 0.8*prev_i2;
      m_q2[i] = 0.2*m_q2[i] + 0.8*prev_q2;
      m_re[i] = m_i2[i]*prev_i2 + m_q2[i]*prev_q2;
      m_im[i] = m_i2[i]*prev_q2 - m_q2[i]*prev_i2;
      m_re[i] = 0.2*m_re[i] + 0.8*prev_re;
      m_im[i] = 0.2*m_im[i] + 0.8*prev_im;
      if(m_im[i]!=0.0 && m_re[i]!=0.0)
         m_period[i] = 360.0/(MathArctan(m_im[i]/m_re[i])*180.0/M_PI);
      else
         m_period[i] = prev_period;
      if(m_period[i]>1.5*prev_period)
         m_period[i]=1.5*prev_period;
      if(m_period[i]<0.67*prev_period)
         m_period[i]=0.67*prev_period;
      if(m_period[i]<6)
         m_period[i]=6;
      if(m_period[i]>50)
         m_period[i]=50;
      m_period[i] = 0.2*m_period[i] + 0.8*prev_period;
      m_smooth_period[i] = 0.33*m_period[i] + 0.67*prev_smooth_period;
      if(m_i1[i]!=0.0)
         m_phase[i] = (MathArctan(m_q1[i]/m_i1[i])*180.0/M_PI);
      else
         m_phase[i] = prev_phase;
      double delta_phase = prev_phase - m_phase[i];
      if(delta_phase<1.0)
         delta_phase=1.0;
      m_alpha[i] = m_fast_limit/delta_phase;
      if(m_alpha[i]<m_slow_limit)
         m_alpha[i]=m_slow_limit;
      if(m_alpha[i]>m_fast_limit)
         m_alpha[i]=m_fast_limit;
      mama_out[i] = m_alpha[i]*m_price[i] + (1-m_alpha[i])*prev_mama;
      fama_out[i] = 0.5*m_alpha[i]*mama_out[i] + (1-0.5*m_alpha[i])*prev_fama;
     }
  }

//+------------------------------------------------------------------+
//| CMAMACalculator: Prepares the standard source price series.      |
//+------------------------------------------------------------------+
bool CMAMACalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   switch(price_type)
     {
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
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
     }
   return true;
  }

//+==================================================================+
//|                                                                  |
//|             CLASS 2: CMAMACalculator_HA (Heikin Ashi)            |
//|                                                                  |
//+==================================================================+
class CMAMACalculator_HA : public CMAMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CMAMACalculator_HA: Prepares the Heikin Ashi source price.       |
//+------------------------------------------------------------------+
bool CMAMACalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);
   switch(price_type)
     {
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
            m_price[i] = (ha_high[i]+ha_low[i]+2*ha_close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
