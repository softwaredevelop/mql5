//+------------------------------------------------------------------+
//|                                 Fisher_Transform_Calculator.mqh  |
//|      Calculation engine for the John Ehlers' Fisher Transform.   |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CFisherTransformCalculator (Base Class)       |
//|                                                                  |
//+==================================================================+
class CFisherTransformCalculator
  {
protected:
   int               m_period;
   double            m_alpha;
   double            m_price[]; // Will hold Median Price (Standard or HA)

   // CORRECTED: Added close[] for the derived class
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CFisherTransformCalculator(void) {};
   virtual          ~CFisherTransformCalculator(void) {};

   bool              Init(int period, double alpha);
   // CORRECTED: Added open[] and close[] for the derived class
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &fisher_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
bool CFisherTransformCalculator::Init(int period, double alpha)
  {
   m_period = (period < 2) ? 2 : period;
   m_alpha  = alpha;
   return true;
  }

//+------------------------------------------------------------------+
void CFisherTransformCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
      double &fisher_buffer[], double &signal_buffer[])
  {
   if(rates_total < m_period)
      return;
   if(!PreparePriceSeries(rates_total, open, high, low, close))
      return;

   double value1 = 0, value1_prev = 0;
   double fish = 0, fish_prev = 0;

   for(int i = 0; i < rates_total; i++)
     {
      if(i < m_period -1)
         continue;

      int high_idx = ArrayMaximum(m_price, i - m_period + 1, m_period);
      int low_idx  = ArrayMinimum(m_price, i - m_period + 1, m_period);
      double maxH = m_price[high_idx];
      double minL = m_price[low_idx];

      double norm_price = 0.0;
      if(maxH - minL != 0)
         norm_price = 2.0 * ((m_price[i] - minL) / (maxH - minL) - 0.5);

      value1 = m_alpha * norm_price + (1.0 - m_alpha) * value1_prev;

      value1 = fmin(0.999, fmax(-0.999, value1));

      fish = 0.5 * log((1.0 + value1) / (1.0 - value1)) + 0.5 * fish_prev;

      fisher_buffer[i] = fish;
      signal_buffer[i] = fish_prev;

      value1_prev = value1;
      fish_prev = fish;
     }
  }

//+------------------------------------------------------------------+
bool CFisherTransformCalculator::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);
   for(int i=0; i<rates_total; i++)
      m_price[i] = (high[i]+low[i])/2.0;
   return true;
  }

//+==================================================================+
class CFisherTransformCalculator_HA : public CFisherTransformCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   // CORRECTED: Signature now matches the base class
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CFisherTransformCalculator_HA::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

// CORRECTED: Pass the full 'close' array to the calculator
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_price, rates_total);
   for(int i=0; i<rates_total; i++)
      m_price[i] = (ha_high[i]+ha_low[i])/2.0;
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
