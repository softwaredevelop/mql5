//+------------------------------------------------------------------+
//|                                   Fourier_Series_Calculator.mqh  |
//|      Calculation engine for the John Ehlers' Fourier Series.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CFourierSeriesCalculator (Base Class)         |
//|                                                                  |
//+==================================================================+
class CFourierSeriesCalculator
  {
protected:
   int               m_period;
   double            m_bandwidth;
   double            m_price[];

   // Filter coefficients
   double            L1, G1, S1;
   double            L2, G2, S2;
   double            L3, G3, S3;

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CFourierSeriesCalculator(void) {};
   virtual          ~CFourierSeriesCalculator(void) {};

   bool              Init(int period, double bandwidth);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &wave_buffer[], double &roc_buffer[]);
  };

//+------------------------------------------------------------------+
bool CFourierSeriesCalculator::Init(int period, double bandwidth)
  {
   m_period = (period < 10) ? 10 : period;
   m_bandwidth = bandwidth;

// Pre-calculate filter coefficients
   L1 = cos(2 * M_PI / m_period);
   G1 = cos(m_bandwidth * 2 * M_PI / m_period);
   S1 = 1.0 / G1 - sqrt(1.0 / (G1 * G1) - 1.0);

   L2 = cos(2 * M_PI / (m_period / 2.0));
   G2 = cos(m_bandwidth * 2 * M_PI / (m_period / 2.0));
   S2 = 1.0 / G2 - sqrt(1.0 / (G2 * G2) - 1.0);

   L3 = cos(2 * M_PI / (m_period / 3.0));
   G3 = cos(m_bandwidth * 2 * M_PI / (m_period / 3.0));
   S3 = 1.0 / G3 - sqrt(1.0 / (G3 * G3) - 1.0);

   return true;
  }

//+------------------------------------------------------------------+
void CFourierSeriesCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &wave_buffer[], double &roc_buffer[])
  {
   if(rates_total < m_period * 2)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

// Intermediate buffers
   double bp1[], bp2[], bp3[], q1[], q2[], q3[];
   ArrayResize(bp1, rates_total);
   ArrayResize(bp2, rates_total);
   ArrayResize(bp3, rates_total);
   ArrayResize(q1, rates_total);
   ArrayResize(q2, rates_total);
   ArrayResize(q3, rates_total);

// State variables for recursive filters
   double bp1_p1=0, bp1_p2=0, bp2_p1=0, bp2_p2=0, bp3_p1=0, bp3_p2=0;

   for(int i = 2; i < rates_total; i++)
     {
      // Step 2: Band-Pass Filters
      bp1[i] = 0.5 * (1.0 - S1) * (m_price[i] - m_price[i-2]) + L1 * (1.0 + S1) * bp1_p1 - S1 * bp1_p2;
      bp2[i] = 0.5 * (1.0 - S2) * (m_price[i] - m_price[i-2]) + L2 * (1.0 + S2) * bp2_p1 - S2 * bp2_p2;
      bp3[i] = 0.5 * (1.0 - S3) * (m_price[i] - m_price[i-2]) + L3 * (1.0 + S3) * bp3_p1 - S3 * bp3_p2;

      // Step 3: Quadrature Components
      q1[i] = (m_period / (2.0 * M_PI)) * (bp1[i] - bp1[i-1]);
      q2[i] = (m_period / (2.0 * M_PI)) * (bp2[i] - bp2[i-1]);
      q3[i] = (m_period / (2.0 * M_PI)) * (bp3[i] - bp3[i-1]);

      // Update state variables
      bp1_p2 = bp1_p1;
      bp1_p1 = bp1[i];
      bp2_p2 = bp2_p1;
      bp2_p1 = bp2[i];
      bp3_p2 = bp3_p1;
      bp3_p1 = bp3[i];
     }

   for(int i = m_period * 2 -1; i < rates_total; i++)
     {
      // Step 4: Calculate Power
      double p1=0, p2=0, p3=0;
      for(int j = 0; j < m_period; j++)
        {
         p1 += bp1[i-j]*bp1[i-j] + q1[i-j]*q1[i-j];
         p2 += bp2[i-j]*bp2[i-j] + q2[i-j]*q2[i-j];
         p3 += bp3[i-j]*bp3[i-j] + q3[i-j]*q3[i-j];
        }

      // Step 5: Synthesize Wave
      if(p1 > 0)
        {
         wave_buffer[i] = bp1[i] + sqrt(p2/p1)*bp2[i] + sqrt(p3/p1)*bp3[i];
        }

      // Step 6: Optional ROC
      if(i > 1)
         roc_buffer[i] = (m_period / (4.0 * M_PI)) * (wave_buffer[i] - wave_buffer[i-2]);
     }
  }

//+------------------------------------------------------------------+
bool CFourierSeriesCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);
// Ehlers' example uses Median Price
   for(int i=0; i<rates_total; i++)
      m_price[i] = (high[i]+low[i])/2.0;
   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CFourierSeriesCalculator_HA : public CFourierSeriesCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CFourierSeriesCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);
   ArrayResize(m_price, rates_total);
   for(int i=0; i<rates_total; i++)
      m_price[i] = (ha_high[i]+ha_low[i])/2.0;
   return true;
  }
//+------------------------------------------------------------------+
