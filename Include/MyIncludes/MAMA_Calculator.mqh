//+------------------------------------------------------------------+
//|                                              MAMA_Calculator.mqh |
//|      Calculation engine for the John Ehlers' MAMA and FAMA.      |
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
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CMAMACalculator(void) {};
   virtual          ~CMAMACalculator(void) {};

   bool              Init(double fast_limit, double slow_limit);
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
   if(rates_total < 50) // MAMA needs a significant warmup period
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

// --- State variables for full recalculation loop ---
   double smooth=0, detrender=0, I1=0, Q1=0;
   double jI=0, jQ=0, I2=0, Q2=0, Re=0, Im=0;
   double period=0, smooth_period=0, phase=0, delta_phase=0;

   double I1_p[7]= {0}, Q1_p[7]= {0}, detrender_p[7]= {0}, smooth_p[5]= {0};
   double I2_p[2]= {0}, Q2_p[2]= {0};
   double Re_p[2]= {0}, Im_p[2]= {0};
   double period_p[2]= {0}, smooth_period_p[2]= {0};
   double phase_p[2]= {0};
   double mama_prev=0, fama_prev=0;

// --- Full recalculation loop for stability ---
   for(int i = 0; i < rates_total; i++)
     {
      // Shift history
      for(int k=6; k>0; k--)
        {
         I1_p[k]=I1_p[k-1];
         Q1_p[k]=Q1_p[k-1];
         detrender_p[k]=detrender_p[k-1];
        }
      for(int k=4; k>0; k--)
        {
         smooth_p[k]=smooth_p[k-1];
        }
      I2_p[1]=I2_p[0];
      Q2_p[1]=Q2_p[0];
      Re_p[1]=Re_p[0];
      Im_p[1]=Im_p[0];
      period_p[1]=period_p[0];
      smooth_period_p[1]=smooth_period_p[0];
      phase_p[1]=phase_p[0];

      // --- Calculation starts after a few bars ---
      if(i > 5)
        {
         // 1. Smoothing
         smooth = (4*m_price[i] + 3*m_price[i-1] + 2*m_price[i-2] + m_price[i-3]) / 10.0;
         smooth_p[0] = smooth;

         // 2. Detrender (Band-pass filter)
         detrender = (0.0962*smooth_p[0] + 0.5769*smooth_p[2] - 0.5769*smooth_p[4] - 0.0962*smooth_p[0]) * (0.075*period_p[1] + 0.54);
         detrender_p[0] = detrender;

         // 3. InPhase and Quadrature components
         Q1 = (0.0962*detrender_p[0] + 0.5769*detrender_p[2] - 0.5769*detrender_p[4] - 0.0962*detrender_p[6]) * (0.075*period_p[1] + 0.54);
         I1 = detrender_p[3];
         I1_p[0] = I1;
         Q1_p[0] = Q1;

         // 4. Phase advance
         jI = (0.0962*I1_p[0] + 0.5769*I1_p[2] - 0.5769*I1_p[4] - 0.0962*I1_p[6]) * (0.075*period_p[1] + 0.54);
         jQ = (0.0962*Q1_p[0] + 0.5769*Q1_p[2] - 0.5769*Q1_p[4] - 0.0962*Q1_p[6]) * (0.075*period_p[1] + 0.54);

         // 5. Phasor addition and smoothing
         I2 = I1 - jQ;
         Q2 = Q1 + jI;
         I2 = 0.2*I2 + 0.8*I2_p[1];
         Q2 = 0.2*Q2 + 0.8*Q2_p[1];
         I2_p[0] = I2;
         Q2_p[0] = Q2;

         // 6. Homodyne Discriminator
         Re = I2*I2_p[1] + Q2*Q2_p[1];
         Im = I2*Q2_p[1] - Q2*I2_p[1];
         Re = 0.2*Re + 0.8*Re_p[1];
         Im = 0.2*Im + 0.8*Im_p[1];
         Re_p[0] = Re;
         Im_p[0] = Im;

         // 7. Cycle Period Measurement
         if(Im!=0.0 && Re!=0.0)
            period = 360.0 / (atan(Im/Re) * 180.0/M_PI);
         if(period > 1.5*period_p[1])
            period = 1.5*period_p[1];
         if(period < 0.67*period_p[1])
            period = 0.67*period_p[1];
         if(period < 6)
            period = 6;
         if(period > 50)
            period = 50;
         period = 0.2*period + 0.8*period_p[1];
         smooth_period = 0.33*period + 0.67*smooth_period_p[1];
         period_p[0] = period;
         smooth_period_p[0] = smooth_period;

         // 8. Delta Phase
         if(I1 != 0.0)
            phase = atan(Q1/I1) * 180.0/M_PI;
         delta_phase = phase_p[1] - phase;
         if(delta_phase < 1.0)
            delta_phase = 1.0;
         phase_p[0] = phase;

         // 9. Adaptive Alpha
         double alpha = m_fast_limit / delta_phase;
         if(alpha < m_slow_limit)
            alpha = m_slow_limit;

         // 10. MAMA and FAMA Calculation
         mama_buffer[i] = alpha * m_price[i] + (1.0 - alpha) * mama_prev;
         fama_buffer[i] = 0.5 * alpha * mama_buffer[i] + (1.0 - 0.5 * alpha) * fama_prev;
        }
      else
        {
         mama_buffer[i] = m_price[i];
         fama_buffer[i] = m_price[i];
        }

      mama_prev = mama_buffer[i];
      fama_prev = fama_buffer[i];
     }
  }

//+------------------------------------------------------------------+
bool CMAMACalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CMAMACalculator_HA : public CMAMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMAMACalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
