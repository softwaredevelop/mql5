//+------------------------------------------------------------------+
//|                                   Fourier_Series_Calculator.mqh  |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CFourierSeriesCalculator                    |
//+==================================================================+
class CFourierSeriesCalculator
  {
protected:
   int               m_period;
   double            m_bandwidth;

   //--- Persistent Buffers
   double            m_price[];
   double            m_bp1[], m_bp2[], m_bp3[];
   double            m_q1[], m_q2[], m_q3[];

   // Filter coefficients
   double            L1, G1, S1;
   double            L2, G2, S2;
   double            L3, G3, S3;

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CFourierSeriesCalculator(void) {};
   virtual          ~CFourierSeriesCalculator(void) {};

   bool              Init(int period, double bandwidth);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &wave_buffer[], double &roc_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
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
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CFourierSeriesCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &wave_buffer[], double &roc_buffer[])
  {
   if(rates_total < m_period * 2)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_bp1, rates_total);
      ArrayResize(m_bp2, rates_total);
      ArrayResize(m_bp3, rates_total);
      ArrayResize(m_q1, rates_total);
      ArrayResize(m_q2, rates_total);
      ArrayResize(m_q3, rates_total);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 1. Calculate Band-Pass Filters and Quadrature (Incremental)
   int loop_start_bp = MathMax(2, start_index);

   if(loop_start_bp == 2)
     {
      // Initialize first few values
      m_bp1[0]=0;
      m_bp1[1]=0;
      m_bp2[0]=0;
      m_bp2[1]=0;
      m_bp3[0]=0;
      m_bp3[1]=0;
      m_q1[0]=0;
      m_q1[1]=0;
      m_q2[0]=0;
      m_q2[1]=0;
      m_q3[0]=0;
      m_q3[1]=0;
     }

   for(int i = loop_start_bp; i < rates_total; i++)
     {
      // Recursive calculation using persistent buffers [i-1], [i-2]
      m_bp1[i] = 0.5 * (1.0 - S1) * (m_price[i] - m_price[i-2]) + L1 * (1.0 + S1) * m_bp1[i-1] - S1 * m_bp1[i-2];
      m_bp2[i] = 0.5 * (1.0 - S2) * (m_price[i] - m_price[i-2]) + L2 * (1.0 + S2) * m_bp2[i-1] - S2 * m_bp2[i-2];
      m_bp3[i] = 0.5 * (1.0 - S3) * (m_price[i] - m_price[i-2]) + L3 * (1.0 + S3) * m_bp3[i-1] - S3 * m_bp3[i-2];

      m_q1[i] = (m_period / (2.0 * M_PI)) * (m_bp1[i] - m_bp1[i-1]);
      m_q2[i] = (m_period / (2.0 * M_PI)) * (m_bp2[i] - m_bp2[i-1]);
      m_q3[i] = (m_period / (2.0 * M_PI)) * (m_bp3[i] - m_bp3[i-1]);
     }

//--- 2. Calculate Power and Synthesize Wave (Incremental)
   int loop_start_wave = MathMax(m_period * 2 - 1, start_index);

   for(int i = loop_start_wave; i < rates_total; i++)
     {
      double p1=0, p2=0, p3=0;

      // Sum power over the period
      for(int j = 0; j < m_period; j++)
        {
         p1 += m_bp1[i-j]*m_bp1[i-j] + m_q1[i-j]*m_q1[i-j];
         p2 += m_bp2[i-j]*m_bp2[i-j] + m_q2[i-j]*m_q2[i-j];
         p3 += m_bp3[i-j]*m_bp3[i-j] + m_q3[i-j]*m_q3[i-j];
        }

      if(p1 > 0)
        {
         wave_buffer[i] = m_bp1[i] + sqrt(p2/p1)*m_bp2[i] + sqrt(p3/p1)*m_bp3[i];
        }
      else
        {
         wave_buffer[i] = 0;
        }

      // ROC
      if(i > 1)
         roc_buffer[i] = (m_period / (4.0 * M_PI)) * (wave_buffer[i] - wave_buffer[i-2]);
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CFourierSeriesCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      // Ehlers' example uses Median Price (HL/2)
      m_price[i] = (high[i] + low[i]) / 2.0;
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CFourierSeriesCalculator_HA                 |
//+==================================================================+
class CFourierSeriesCalculator_HA : public CFourierSeriesCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];
protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CFourierSeriesCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   for(int i = start_index; i < rates_total; i++)
     {
      m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
     }
   return true;
  }
//+------------------------------------------------------------------+
