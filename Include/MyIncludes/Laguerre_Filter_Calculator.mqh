//+------------------------------------------------------------------+
//|                                  Laguerre_Filter_Calculator.mqh  |
//|      Adapter for the Laguerre Filter indicator.                  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include "Laguerre_Engine.mqh"

//+==================================================================+
//|                                                                  |
//|         CLASS 1: CLaguerreFilterCalculator (Base Class)          |
//|                                                                  |
//+==================================================================+
class CLaguerreFilterCalculator
  {
protected:
   CLaguerreEngine   *m_engine;

public:
                     CLaguerreFilterCalculator(void) { m_engine = new CLaguerreEngine(); };
   virtual          ~CLaguerreFilterCalculator(void) { if(CheckPointer(m_engine) != POINTER_INVALID) delete m_engine; };

   bool              Init(double gamma);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &filter_buffer[], double &fir_buffer[]);
  };

bool CLaguerreFilterCalculator::Init(double gamma) { return m_engine.Init(gamma); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CLaguerreFilterCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &filter_buffer[], double &fir_buffer[])
  {
   double L0[], L1[], L2[], L3[], filt[];
   m_engine.CalculateFilter(rates_total, price_type, open, high, low, close, L0, L1, L2, L3, filt);

// Copy the final, weighted Laguerre filter result to the output buffer
   ArrayCopy(filter_buffer, filt, 0, 0, rates_total);

// --- CORRECTED: Calculate the comparative FIR filter using the public getter ---
   if(rates_total > 3)
     {
      double price_data[];
      m_engine.GetPriceBuffer(price_data); // Safely get the price data from the engine

      for(int i = 3; i < rates_total; i++)
        {
         fir_buffer[i] = (price_data[i] + 2.0 * price_data[i-1] + 2.0 * price_data[i-2] + price_data[i-3]) / 6.0;
        }
     }
  }

//+==================================================================+
//|                                                                  |
//|       CLASS 2: CLaguerreFilterCalculator_HA (Heikin Ashi)        |
//|                                                                  |
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
