//+------------------------------------------------------------------+
//|                                     CyclePeriod_Calculator.mqh   |
//|      Calculation engine for John Ehlers' Dominant Cycle Period.  |
//|      Method: Homodyne Discriminator.                             |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CCyclePeriodCalculator
  {
protected:
   //--- Persistent Buffers
   double            m_price[];
   double            m_smooth[];
   double            m_detrender[];
   double            m_q1[];
   double            m_i1[];
   double            m_q2[];
   double            m_i2[];
   double            m_period[];
   double            m_smooth_period[]; // Final output

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CCyclePeriodCalculator(void) {};
   virtual          ~CCyclePeriodCalculator(void) {};

   bool              Init();
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &period_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CCyclePeriodCalculator::Init()
  {
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Homodyne Discriminator)                        |
//+------------------------------------------------------------------+
void CCyclePeriodCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &period_buffer[])
  {
   if(rates_total < 10)
      return;

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// Resize buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_smooth, rates_total);
      ArrayResize(m_detrender, rates_total);
      ArrayResize(m_q1, rates_total);
      ArrayResize(m_i1, rates_total);
      ArrayResize(m_q2, rates_total);
      ArrayResize(m_i2, rates_total);
      ArrayResize(m_period, rates_total);
      ArrayResize(m_smooth_period, rates_total);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// Ehlers' Homodyne Discriminator Logic
   int loop_start = MathMax(6, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      // 1. Smooth Price (4-bar WMA)
      m_smooth[i] = (4*m_price[i] + 3*m_price[i-1] + 2*m_price[i-2] + m_price[i-3]) / 10.0;

      // 2. Detrend (Hilbert Transform component)
      // Amplitude correction factor: 0.0962 for 6-bar period, 0.5769 for 3-bar
      // Ehlers standard detrender:
      double c1 = 0.0962;
      double c2 = 0.5769;

      double detrender_raw = (c1*m_smooth[i] + c2*m_smooth[i-2] - c2*m_smooth[i-4] - c1*m_smooth[i-6]) * (0.075*m_period[i-1] + 0.54);
      m_detrender[i] = detrender_raw;

      // 3. Compute InPhase and Quadrature components
      // Q1 is the detrender delayed by 3 bars (90 degrees of a typical bar cycle)
      m_q1[i] = (c1*m_detrender[i] + c2*m_detrender[i-2] - c2*m_detrender[i-4] - c1*m_detrender[i-6]) * (0.075*m_period[i-1] + 0.54);
      m_i1[i] = m_detrender[i-3];

      // 4. Advance the phase of I1 and Q1 by 90 degrees
      double jI = (c1*m_i1[i] + c2*m_i1[i-2] - c2*m_i1[i-4] - c1*m_i1[i-6]) * (0.075*m_period[i-1] + 0.54);
      double jQ = (c1*m_q1[i] + c2*m_q1[i-2] - c2*m_q1[i-4] - c1*m_q1[i-6]) * (0.075*m_period[i-1] + 0.54);

      // 5. Phasor addition for Homodyne
      m_i2[i] = m_i1[i] - jQ;
      m_q2[i] = m_q1[i] + jI;

      // 6. Smooth the I2 and Q2 components
      m_i2[i] = 0.2*m_i2[i] + 0.8*m_i2[i-1];
      m_q2[i] = 0.2*m_q2[i] + 0.8*m_q2[i-1];

      // 7. Homodyne Discriminator
      double re = m_i2[i]*m_i2[i-1] + m_q2[i]*m_q2[i-1];
      double im = m_i2[i]*m_q2[i-1] - m_q2[i]*m_i2[i-1];

      double period = 0;
      if(im != 0 && re != 0)
         period = 360.0 / (atan(im/re) * 180.0 / M_PI);

      // Fix wrap-around and limits
      if(period > 1.5 * m_period[i-1])
         period = 1.5 * m_period[i-1];
      if(period < 0.67 * m_period[i-1])
         period = 0.67 * m_period[i-1];
      if(period < 6)
         period = 6;
      if(period > 50)
         period = 50;

      m_period[i] = 0.2*period + 0.8*m_period[i-1];

      // 8. Final Smooth (Median Filter equivalent)
      m_smooth_period[i] = 0.33*m_period[i] + 0.67*m_smooth_period[i-1];

      period_buffer[i] = m_smooth_period[i];
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price                                                    |
//+------------------------------------------------------------------+
bool CCyclePeriodCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      // Ehlers typically uses (High+Low)/2
      m_price[i] = (high[i] + low[i]) / 2.0;
     }
   return true;
  }
//+------------------------------------------------------------------+
