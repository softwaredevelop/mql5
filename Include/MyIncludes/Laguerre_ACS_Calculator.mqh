//+------------------------------------------------------------------+
//|                                      Laguerre_ACS_Calculator.mqh |
//|      Adaptive Cyber Cycle: Adaptive Laguerre -> Cyber Cycle.     |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\Laguerre_Filter_Adaptive_Calculator.mqh>
#include <MyIncludes\Cyber_Cycle_Calculator.mqh>

//+==================================================================+
//|           CLASS 1: CLaguerreACSCalculator (Base)                 |
//+==================================================================+
class CLaguerreACSCalculator
  {
protected:
   //--- Composition
   CLaguerreFilterAdaptiveCalculator *m_adaptive_engine;
   CCyberCycleCalculator             *m_cyber_engine;

   //--- Internal Buffer
   double            m_adaptive_buffer[];

   virtual void      CreateEngines(void);

public:
                     CLaguerreACSCalculator(void);
   virtual          ~CLaguerreACSCalculator(void);

   bool              Init(double cyber_alpha);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &cycle_out[], double &signal_out[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreACSCalculator::CLaguerreACSCalculator(void)
  {
   m_adaptive_engine = NULL;
   m_cyber_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreACSCalculator::~CLaguerreACSCalculator(void)
  {
   if(CheckPointer(m_adaptive_engine) != POINTER_INVALID)
      delete m_adaptive_engine;
   if(CheckPointer(m_cyber_engine) != POINTER_INVALID)
      delete m_cyber_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CLaguerreACSCalculator::CreateEngines(void)
  {
   m_adaptive_engine = new CLaguerreFilterAdaptiveCalculator();
   m_cyber_engine = new CCyberCycleCalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreACSCalculator::Init(double cyber_alpha)
  {
   CreateEngines();

   if(CheckPointer(m_adaptive_engine) == POINTER_INVALID || !m_adaptive_engine.Init())
      return false;

   if(CheckPointer(m_cyber_engine) == POINTER_INVALID || !m_cyber_engine.Init(cyber_alpha))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CLaguerreACSCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                       double &cycle_out[], double &signal_out[])
  {
   if(rates_total < 10)
      return;

// Resize internal buffer
   if(ArraySize(m_adaptive_buffer) != rates_total)
      ArrayResize(m_adaptive_buffer, rates_total);

// 1. Calculate Adaptive Laguerre Filter
   m_adaptive_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_adaptive_buffer);

// 2. Calculate Cyber Cycle on the Adaptive Filter output
   m_cyber_engine.CalculateOnArray(rates_total, prev_calculated, m_adaptive_buffer, cycle_out, signal_out);
  }

//+==================================================================+
//|           CLASS 2: CLaguerreACSCalculator_HA                     |
//+==================================================================+
class CLaguerreACSCalculator_HA : public CLaguerreACSCalculator
  {
protected:
   virtual void      CreateEngines(void) override;
  };

//+------------------------------------------------------------------+
//| Factory Override                                                 |
//+------------------------------------------------------------------+
void CLaguerreACSCalculator_HA::CreateEngines(void)
  {
   m_adaptive_engine = new CLaguerreFilterAdaptiveCalculator_HA();
   m_cyber_engine = new CCyberCycleCalculator(); // Cyber engine works on array, so base class is fine
  }
//+------------------------------------------------------------------+
