//+------------------------------------------------------------------+
//|                                     FisherTransform_Calculator.mqh|
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
   int               m_length;

   //--- Persistent Buffers for Incremental Calculation
   double            m_hl2_price[];
   double            m_value_buffer[]; // Intermediate smoothed value

   double            Highest(int period, int current_pos);
   double            Lowest(int period, int current_pos);

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CFisherTransformCalculator(void) {};
   virtual          ~CFisherTransformCalculator(void) {};

   bool              Init(int length);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], double &fisher_buffer[], double &trigger_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CFisherTransformCalculator::Init(int length)
  {
   m_length = (length < 1) ? 1 : length;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CFisherTransformCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], double &fisher_buffer[], double &trigger_buffer[])
  {
   if(rates_total <= m_length)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_hl2_price) != rates_total)
     {
      ArrayResize(m_hl2_price, rates_total);
      ArrayResize(m_value_buffer, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

//--- 4. Calculate Fisher Transform (Incremental Loop)
   int loop_start = MathMax(m_length, start_index);

// Initialization for first bar
   if(loop_start == m_length)
     {
      // We need to initialize m_value_buffer[m_length-1] and fisher_buffer[m_length-1] to 0
      // to avoid garbage values in recursion.
      m_value_buffer[m_length-1] = 0;
      fisher_buffer[m_length-1] = 0;
      trigger_buffer[m_length-1] = 0;
     }

   for(int i = loop_start; i < rates_total; i++)
     {
      double high_ = Highest(m_length, i);
      double low_  = Lowest(m_length, i);
      double range = high_ - low_;
      if(range < _Point)
         range = _Point;

      double price_pos = (m_hl2_price[i] - low_) / range - 0.5;

      // Recursive calculation using persistent m_value_buffer[i-1]
      m_value_buffer[i] = 0.33 * 2 * price_pos + 0.67 * m_value_buffer[i-1];

      if(m_value_buffer[i] > 0.999)
         m_value_buffer[i] = 0.999;
      if(m_value_buffer[i] < -0.999)
         m_value_buffer[i] = -0.999;

      double log_val = 0.5 * MathLog((1 + m_value_buffer[i]) / (1 - m_value_buffer[i]));

      // Recursive calculation using persistent fisher_buffer[i-1] (from indicator)
      fisher_buffer[i] = log_val + 0.5 * fisher_buffer[i-1];
      trigger_buffer[i] = fisher_buffer[i-1];
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CFisherTransformCalculator::PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Optimized copy loop
   for(int i = start_index; i < rates_total; i++)
     {
      m_hl2_price[i] = (high[i] + low[i]) / 2.0;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Highest                                                          |
//+------------------------------------------------------------------+
double CFisherTransformCalculator::Highest(int period, int current_pos)
  {
   double res = m_hl2_price[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res < m_hl2_price[index])
         res = m_hl2_price[index];
     }
   return(res);
  }

//+------------------------------------------------------------------+
//| Lowest                                                           |
//+------------------------------------------------------------------+
double CFisherTransformCalculator::Lowest(int period, int current_pos)
  {
   double res = m_hl2_price[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res > m_hl2_price[index])
         res = m_hl2_price[index];
     }
   return(res);
  }

//+==================================================================+
//|         CLASS 2: CFisherTransformCalculator_HA (Heikin Ashi)     |
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
// Resize internal HA buffers
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

//--- Copy to m_hl2_price (Optimized loop)
   for(int i = start_index; i < rates_total; i++)
     {
      m_hl2_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
     }
   return true;
  }
//+------------------------------------------------------------------+
