//+------------------------------------------------------------------+
//|                                     Laguerre_RSI_Calculator.mqh  |
//|      Adapter for the Laguerre RSI indicator.                     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include "Laguerre_Engine.mqh"

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CLaguerreRSICalculator (Base Class)           |
//|                                                                  |
//+==================================================================+
class CLaguerreRSICalculator
  {
protected:
   CLaguerreEngine   *m_engine;

public:
                     CLaguerreRSICalculator(void) { m_engine = new CLaguerreEngine(); };
   virtual          ~CLaguerreRSICalculator(void) { if(CheckPointer(m_engine) != POINTER_INVALID) delete m_engine; };

   bool              Init(double gamma);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &lrsi_buffer[]);
  };

// CORRECTED: Pass the required SOURCE_PRICE to the engine's Init method.
bool CLaguerreRSICalculator::Init(double gamma) { return m_engine.Init(gamma, SOURCE_PRICE); }

//+------------------------------------------------------------------+
void CLaguerreRSICalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &lrsi_buffer[])
  {
   if(rates_total < 2)
      return;

   double L0[], L1[], L2[], L3[];
   double dummy_filt[]; // Dummy buffer to satisfy the engine's new signature
   m_engine.CalculateFilter(rates_total, price_type, open, high, low, close, L0, L1, L2, L3, dummy_filt);

   for(int i = 1; i < rates_total; i++)
     {
      double cu = 0.0, cd = 0.0;
      if(L0[i] >= L1[i])
         cu = L0[i] - L1[i];
      else
         cd = L1[i] - L0[i];
      if(L1[i] >= L2[i])
         cu += L1[i] - L2[i];
      else
         cd += L2[i] - L1[i];
      if(L2[i] >= L3[i])
         cu += L2[i] - L3[i];
      else
         cd += L3[i] - L2[i];

      double lrsi_value;
      if(cu + cd > 0.0)
         lrsi_value = 100.0 * cu / (cu + cd);
      else
         lrsi_value = (i > 0) ? lrsi_buffer[i-1] : 50.0;

      if(lrsi_value > 100.0)
         lrsi_value = 100.0;
      if(lrsi_value < 0.0)
         lrsi_value = 0.0;

      lrsi_buffer[i] = lrsi_value;
     }
  }

//+==================================================================+
class CLaguerreRSICalculator_HA : public CLaguerreRSICalculator
  {
public:
                     CLaguerreRSICalculator_HA(void)
     {
      if(CheckPointer(m_engine) != POINTER_INVALID)
         delete m_engine;
      m_engine = new CLaguerreEngine_HA();
     };
  };
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
