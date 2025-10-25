//+------------------------------------------------------------------+
//|                                   CG_Oscillator_Calculator.mqh   |
//|      Calculation engine for the John Ehlers' CG Oscillator.      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+================================----------------==================+
//|                                                                  |
//|           CLASS 1: CCGOscillatorCalculator (Base Class)          |
//|                                                                  |
//+==================================================================+
class CCGOscillatorCalculator
  {
protected:
   int               m_period;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CCGOscillatorCalculator(void) {};
   virtual          ~CCGOscillatorCalculator(void) {};

   bool              Init(int period);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &cg_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
bool CCGOscillatorCalculator::Init(int period)
  {
   m_period = (period < 2) ? 2 : period;
   return true;
  }

//+------------------------------------------------------------------+
void CCGOscillatorCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                        double &cg_buffer[], double &signal_buffer[])
  {
   if(rates_total < m_period)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

// Full recalculation for stability
   for(int i = m_period - 1; i < rates_total; i++)
     {
      double numerator = 0;
      double denominator = 0;

      // Inner loop to calculate the weighted and simple sums
      for(int j = 0; j < m_period; j++)
        {
         // Ehlers' code: count from 0 to Length-1, weight is (1+count)
         // This corresponds to j from 0 to m_period-1, weight is (j+1)
         // The price is Price[count], which is m_price[i-j] in our chronological array
         double current_price = m_price[i - j];
         numerator += (j + 1) * current_price;
         denominator += current_price;
        }

      if(denominator != 0)
        {
         cg_buffer[i] = -numerator / denominator;
        }
     }

// Create the signal line (1-bar delay)
   for(int i = m_period; i < rates_total; i++)
     {
      signal_buffer[i] = cg_buffer[i-1];
     }
  }

//+------------------------------------------------------------------+
bool CCGOscillatorCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);
// Ehlers' example uses Median Price
   for(int i=0; i<rates_total; i++)
      m_price[i] = (high[i]+low[i])/2.0;
   return true;
  }

//+==================================================================+
class CCGOscillatorCalculator_HA : public CCGOscillatorCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CCGOscillatorCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_price, rates_total);
// Use Median Price of Heikin Ashi candles
   for(int i=0; i<rates_total; i++)
      m_price[i] = (ha_high[i]+ha_low[i])/2.0;
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
