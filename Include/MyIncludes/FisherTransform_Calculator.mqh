//+------------------------------------------------------------------+
//|                                     FisherTransform_Calculator.mqh|
//|  Calculation engine for Standard and Heikin Ashi Fisher Transform.|
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
   int               m_length;
   double            m_hl2_price[];

   double            Highest(int period, int current_pos);
   double            Lowest(int period, int current_pos);

   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CFisherTransformCalculator(void) {};
   virtual          ~CFisherTransformCalculator(void) {};

   bool              Init(int length);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &fisher_buffer[], double &trigger_buffer[]);
  };

//+------------------------------------------------------------------+
//| CFisherTransformCalculator: Initialization                       |
//+------------------------------------------------------------------+
bool CFisherTransformCalculator::Init(int length)
  {
   m_length = (length < 1) ? 1 : length;
   return true;
  }

//+------------------------------------------------------------------+
//| CFisherTransformCalculator: Main Calculation Method              |
//+------------------------------------------------------------------+
void CFisherTransformCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &fisher_buffer[], double &trigger_buffer[])
  {
   if(rates_total <= m_length)
      return;
   if(!PreparePriceSeries(rates_total, open, high, low, close))
      return;

   double value_buffer[];
   ArrayResize(value_buffer, rates_total);

   for(int i = 1; i < rates_total; i++)
     {
      if(i < m_length)
         continue;

      double high_ = Highest(m_length, i);
      double low_  = Lowest(m_length, i);
      double range = high_ - low_;
      if(range < _Point)
         range = _Point;

      double price_pos = (m_hl2_price[i] - low_) / range - 0.5;
      value_buffer[i] = 0.33 * 2 * price_pos + 0.67 * value_buffer[i-1];

      if(value_buffer[i] > 0.999)
         value_buffer[i] = 0.999;
      if(value_buffer[i] < -0.999)
         value_buffer[i] = -0.999;

      double log_val = 0.5 * MathLog((1 + value_buffer[i]) / (1 - value_buffer[i]));
      if(i == m_length)
         fisher_buffer[i] = log_val;
      else
         fisher_buffer[i] = log_val + 0.5 * fisher_buffer[i-1];

      trigger_buffer[i] = fisher_buffer[i-1];
     }
  }

//+------------------------------------------------------------------+
//| CFisherTransformCalculator: Prepares the standard source price.  |
//+------------------------------------------------------------------+
bool CFisherTransformCalculator::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_hl2_price, rates_total);
   for(int i=0; i<rates_total; i++)
     {
      m_hl2_price[i] = (high[i] + low[i]) / 2.0;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Finds the highest value in the internal price buffer.            |
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
//| Finds the lowest value in the internal price buffer.             |
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
//|                                                                  |
//|         CLASS 2: CFisherTransformCalculator_HA (Heikin Ashi)     |
//|                                                                  |
//+==================================================================+
class CFisherTransformCalculator_HA : public CFisherTransformCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CFisherTransformCalculator_HA: Prepares the HA source price.     |
//+------------------------------------------------------------------+
bool CFisherTransformCalculator_HA::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_hl2_price, rates_total);
   for(int i=0; i<rates_total; i++)
     {
      m_hl2_price[i] = (ha_high[i] + ha_low[i]) / 2.0;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
