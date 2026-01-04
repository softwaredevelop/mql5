//+------------------------------------------------------------------+
//|                                 Fisher_Transform_Calculator.mqh  |
//|      Calculation engine for the John Ehlers' Fisher Transform.   |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|           CLASS 1: CFisherTransformCalculator (Base Class)       |
//+==================================================================+
class CFisherTransformCalculator
  {
protected:
   int               m_period;
   double            m_alpha;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];
   double            m_value1[]; // Smoothed normalized price
   double            m_fish[];   // Fisher Transform value

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CFisherTransformCalculator(void) {};
   virtual          ~CFisherTransformCalculator(void) {};

   bool              Init(int period, double alpha);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &fisher_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CFisherTransformCalculator::Init(int period, double alpha)
  {
   m_period = (period < 2) ? 2 : period;
   m_alpha  = alpha;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CFisherTransformCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
      double &fisher_buffer[], double &signal_buffer[])
  {
   if(rates_total < m_period)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_value1, rates_total);
      ArrayResize(m_fish, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

//--- 4. Calculate Fisher Transform (Incremental Loop)
   int loop_start = MathMax(m_period - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      // Find Highest High and Lowest Low over period
      // Optimization: For small periods (10), loop is fast.
      int high_idx = ArrayMaximum(m_price, i - m_period + 1, m_period);
      int low_idx  = ArrayMinimum(m_price, i - m_period + 1, m_period);
      double maxH = m_price[high_idx];
      double minL = m_price[low_idx];

      double norm_price = 0.0;
      if(maxH - minL != 0)
         norm_price = 2.0 * ((m_price[i] - minL) / (maxH - minL) - 0.5);

      // Recursive smoothing
      // Use persistent buffer [i-1]
      double value1_prev = (i > 0) ? m_value1[i-1] : 0;
      m_value1[i] = m_alpha * norm_price + (1.0 - m_alpha) * value1_prev;

      // Clamp value to avoid log error
      if(m_value1[i] > 0.999)
         m_value1[i] = 0.999;
      if(m_value1[i] < -0.999)
         m_value1[i] = -0.999;

      // Fisher calculation
      double fish_prev = (i > 0) ? m_fish[i-1] : 0;
      m_fish[i] = 0.5 * log((1.0 + m_value1[i]) / (1.0 - m_value1[i])) + 0.5 * fish_prev;

      fisher_buffer[i] = m_fish[i];
      signal_buffer[i] = fish_prev; // Signal is 1-bar delayed Fisher
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CFisherTransformCalculator::PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      // Ehlers uses (High+Low)/2
      m_price[i] = (high[i] + low[i]) / 2.0;
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CFisherTransformCalculator_HA               |
//+==================================================================+
class CFisherTransformCalculator_HA : public CFisherTransformCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CFisherTransformCalculator_HA::PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   for(int i = start_index; i < rates_total; i++)
     {
      m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
     }
   return true;
  }
//+------------------------------------------------------------------+
