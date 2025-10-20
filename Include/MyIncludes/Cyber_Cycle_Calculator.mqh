//+------------------------------------------------------------------+
//|                                        Cyber_Cycle_Calculator.mqh|
//|      Calculation engine for the John Ehlers' Cyber Cycle.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CCyberCycleCalculator (Base Class)            |
//|                                                                  |
//+==================================================================+
class CCyberCycleCalculator
  {
protected:
   double            m_alpha;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CCyberCycleCalculator(void) {};
   virtual          ~CCyberCycleCalculator(void) {};

   bool              Init(double alpha);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &cycle_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
bool CCyberCycleCalculator::Init(double alpha)
  {
   m_alpha = alpha;
   return true;
  }

//+------------------------------------------------------------------+
void CCyberCycleCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                                      double &cycle_buffer[], double &signal_buffer[])
  {
   if(rates_total < 7)
      return;
   if(!PreparePriceSeries(rates_total, open, high, low, close))
      return;

   double smooth_buffer[];
   ArrayResize(smooth_buffer, rates_total);

// Step 1: Pre-smoothing with a 4-bar FIR filter
   for(int i = 3; i < rates_total; i++)
     {
      smooth_buffer[i] = (m_price[i] + 2.0 * m_price[i-1] + 2.0 * m_price[i-2] + m_price[i-3]) / 6.0;
     }

   double cycle_prev = 0, cycle_prev2 = 0;

// Step 2 & 3: Calculate Cyber Cycle with initialization
   for(int i = 0; i < rates_total; i++)
     {
      double cycle_val = 0;
      if(i < 7) // Initialization period as per Ehlers' article
        {
         if(i > 1)
            cycle_val = (m_price[i] - 2.0 * m_price[i-1] + m_price[i-2]) / 4.0;
        }
      else // Main recursive calculation
        {
         double term1 = (1.0 - 0.5 * m_alpha) * (1.0 - 0.5 * m_alpha) * (smooth_buffer[i] - 2.0 * smooth_buffer[i-1] + smooth_buffer[i-2]);
         double term2 = 2.0 * (1.0 - m_alpha) * cycle_prev;
         double term3 = (1.0 - m_alpha) * (1.0 - m_alpha) * cycle_prev2;
         cycle_val = term1 + term2 - term3;
        }

      cycle_buffer[i] = cycle_val;

      // Step 4: Create the signal line (2-bar delay)
      if(i > 1)
         signal_buffer[i] = cycle_buffer[i-2];
      else
         signal_buffer[i] = 0;

      // Update previous values for next iteration
      cycle_prev2 = cycle_prev;
      cycle_prev = cycle_val;
     }
  }

//+------------------------------------------------------------------+
bool CCyberCycleCalculator::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);
// Ehlers' original paper uses Median Price
   for(int i=0; i<rates_total; i++)
      m_price[i] = (high[i]+low[i])/2.0;
   return true;
  }

//+==================================================================+
class CCyberCycleCalculator_HA : public CCyberCycleCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CCyberCycleCalculator_HA::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
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
//+------------------------------------------------------------------+
