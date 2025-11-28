//+------------------------------------------------------------------+
//|                                  Laguerre_Filter_Calculator.mqh  |
//|      Adapter for the Laguerre Filter indicator.                  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Laguerre_Engine.mqh>

//+==================================================================+
class CLaguerreFilterCalculator
  {
protected:
   CLaguerreEngine   *m_engine;

public:
                     CLaguerreFilterCalculator(void) { m_engine = new CLaguerreEngine(); };
   virtual          ~CLaguerreFilterCalculator(void) { if(CheckPointer(m_engine) != POINTER_INVALID) delete m_engine; };

   bool              Init(double gamma, ENUM_INPUT_SOURCE source_type);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &filter_buffer[], double &fir_buffer[]);
  };

//+------------------------------------------------------------------+
bool CLaguerreFilterCalculator::Init(double gamma, ENUM_INPUT_SOURCE source_type)
  {
   return m_engine.Init(gamma, source_type);
  }

//+------------------------------------------------------------------+
void CLaguerreFilterCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &filter_buffer[], double &fir_buffer[])
  {
// Note: The engine calculates L0..L3 internally, we just need the final output.
// But the engine's CalculateFilter method signature was designed to return all L buffers for debugging/other indicators.
// We can simplify the engine or just pass dummy buffers if we don't need them,
// OR update the engine to store them internally (which we did in the previous step!).

// Wait, in the previous step (Laguerre_Engine.mqh), I changed CalculateFilter to:
// void CalculateFilter(..., double &filt_buffer[])
// It no longer returns L0..L3 as arguments because they are internal members now.
// So we update the call here.

   m_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, filter_buffer);

// FIR Filter Calculation (Simple Moving Average of Price)
// We can optimize this too.
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start_index < 3)
      start_index = 3;

   if(rates_total > 3)
     {
      double price_data[];
      m_engine.GetPriceBuffer(price_data); // This gets the full price array

      for(int i = start_index; i < rates_total; i++)
        {
         fir_buffer[i] = (price_data[i] + 2.0 * price_data[i-1] + 2.0 * price_data[i-2] + price_data[i-3]) / 6.0;
        }
     }
  }

//+==================================================================+
class CLaguerreFilterCalculator_HA : public CLaguerreFilterCalculator
  {
public:
                     CLaguerreFilterCalculator_HA(void)
     {
      if(CheckPointer(m_engine) != POINTER_INVALID)
         delete m_engine;
      m_engine = new CLaguerreEngine_HA();
     };
  };
//+------------------------------------------------------------------+
