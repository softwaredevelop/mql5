//+------------------------------------------------------------------+
//|                           MACD_Laguerre_Line_Calculator.mqh      |
//|      VERSION 1.20: Optimized for incremental calculation.        |
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

   bool              Init(double gamma1, double gamma2);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
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
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMACDLaguerreLineCalculator::CMACDLaguerreLineCalculator(void)
  {
   m_fast_engine = NULL;
   m_slow_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMACDLaguerreLineCalculator::~CMACDLaguerreLineCalculator(void)
  {
   if(CheckPointer(m_fast_engine) != POINTER_INVALID)
      delete m_fast_engine;
   if(CheckPointer(m_slow_engine) != POINTER_INVALID)
      delete m_slow_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
CLaguerreEngine *CMACDLaguerreLineCalculator::CreateEngineInstance(void) { return new CLaguerreEngine(); }
CLaguerreEngine *CMACDLaguerreLineCalculator_HA::CreateEngineInstance(void) { return new CLaguerreEngine_HA(); }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMACDLaguerreLineCalculator::Init(double gamma1, double gamma2)
  {
//--- Automatically determine which gamma is fast (smaller) and slow (larger)
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
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CMACDLaguerreLineCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &macd_line[])
  {
   if(rates_total < 2)
      return;

//--- 1. Calculate Fast and Slow Laguerre Filters (Incremental)
   double fast_filter[], slow_filter[];
// Note: The engine resizes them.

   m_fast_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, fast_filter);
   m_slow_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, slow_filter);

//--- 2. Calculate MACD Line (Incremental Loop)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start_index; i < rates_total; i++)
      macd_line[i] = fast_filter[i] - slow_filter[i];
  }
//+------------------------------------------------------------------+
