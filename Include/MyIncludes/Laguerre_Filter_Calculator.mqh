//+------------------------------------------------------------------+
//|                                  Laguerre_Filter_Calculator.mqh  |
//|      Adapter for the Laguerre Filter indicator.                  |
//|      VERSION 1.30: Optimized FIR calculation using direct getter |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.30"

#include <MyIncludes\Laguerre_Engine.mqh>

//+==================================================================+
//|             CLASS: CLaguerreFilterCalculator                     |
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
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreFilterCalculator::Init(double gamma, ENUM_INPUT_SOURCE source_type)
  {
   return m_engine.Init(gamma, source_type);
  }

//+------------------------------------------------------------------+
//| Calculate (Optimized)                                            |
//+------------------------------------------------------------------+
void CLaguerreFilterCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &filter_buffer[], double &fir_buffer[])
  {
   m_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, filter_buffer);

// FIR Filter Calculation (Optimized using the dynamic inline GetPrice getter)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start_index < 3)
      start_index = 3;

   if(rates_total > 3)
     {
      // FIXED: Uses direct m_engine.GetPrice() to prevent massive memory copy overhead per tick!
      for(int i = start_index; i < rates_total; i++)
        {
         fir_buffer[i] = (m_engine.GetPrice(i) + 2.0 * m_engine.GetPrice(i-1) + 2.0 * m_engine.GetPrice(i-2) + m_engine.GetPrice(i-3)) / 6.0;
        }
     }
  }

//+==================================================================+
//|             CLASS 2: CLaguerreFilterCalculator_HA                |
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
//+------------------------------------------------------------------+
