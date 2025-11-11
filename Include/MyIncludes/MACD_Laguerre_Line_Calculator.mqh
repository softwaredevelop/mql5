//+------------------------------------------------------------------+
//|                           MACD_Laguerre_Line_Calculator.mqh      |
//|         VERSION 1.10: Corrected Gamma logic (smaller = faster).  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Laguerre_Engine.mqh>

//+==================================================================+
class CMACDLaguerreLineCalculator
  {
protected:
   double            m_fast_gamma, m_slow_gamma;
   CLaguerreEngine   *m_fast_engine;
   CLaguerreEngine   *m_slow_engine;

   virtual CLaguerreEngine *CreateEngineInstance(void);

public:
                     CMACDLaguerreLineCalculator(void);
   virtual          ~CMACDLaguerreLineCalculator(void);

   bool              Init(double gamma1, double gamma2); // Changed signature
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &macd_line[]);
  };

//--- Derived class for Heikin Ashi version ---
class CMACDLaguerreLineCalculator_HA : public CMACDLaguerreLineCalculator
  {
protected:
   virtual CLaguerreEngine *CreateEngineInstance(void) override;
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMACDLaguerreLineCalculator::CMACDLaguerreLineCalculator(void)
  {
   m_fast_engine = NULL;
   m_slow_engine = NULL;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMACDLaguerreLineCalculator::~CMACDLaguerreLineCalculator(void)
  {
   if(CheckPointer(m_fast_engine) != POINTER_INVALID)
      delete m_fast_engine;
   if(CheckPointer(m_slow_engine) != POINTER_INVALID)
      delete m_slow_engine;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CLaguerreEngine *CMACDLaguerreLineCalculator::CreateEngineInstance(void) { return new CLaguerreEngine(); }
CLaguerreEngine *CMACDLaguerreLineCalculator_HA::CreateEngineInstance(void) { return new CLaguerreEngine_HA(); }

//--- CORRECTED and more ROBUST Init method ---
bool CMACDLaguerreLineCalculator::Init(double gamma1, double gamma2)
  {
//--- Automatically determine which gamma is fast (smaller) and slow (larger) ---
   m_fast_gamma = MathMin(gamma1, gamma2);
   m_slow_gamma = MathMax(gamma1, gamma2);

   m_fast_engine = CreateEngineInstance();
   m_slow_engine = CreateEngineInstance();

   if(CheckPointer(m_fast_engine) == POINTER_INVALID || !m_fast_engine.Init(m_fast_gamma, SOURCE_PRICE) ||
      CheckPointer(m_slow_engine) == POINTER_INVALID || !m_slow_engine.Init(m_slow_gamma, SOURCE_PRICE))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMACDLaguerreLineCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &macd_line[])
  {
   if(rates_total < 2)
      return;

   double fast_filter[], slow_filter[];
   double L0_dummy[], L1_dummy[], L2_dummy[], L3_dummy[];

   m_fast_engine.CalculateFilter(rates_total, price_type, open, high, low, close, L0_dummy, L1_dummy, L2_dummy, L3_dummy, fast_filter);
   m_slow_engine.CalculateFilter(rates_total, price_type, open, high, low, close, L0_dummy, L1_dummy, L2_dummy, L3_dummy, slow_filter);

   for(int i = 0; i < rates_total; i++)
      macd_line[i] = fast_filter[i] - slow_filter[i];
  }
//+------------------------------------------------------------------+
