//+------------------------------------------------------------------+
//|                              Laguerre_Cyber_Cycle_Calculator.mqh |
//|      Standard Laguerre Filter -> Cyber Cycle.                    |
//|      VERSION 2.00: Added flexible Signal Line support.           |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\Laguerre_Engine.mqh>
#include <MyIncludes\Cyber_Cycle_Calculator.mqh>

//+==================================================================+
//|           CLASS 1: CLaguerreCyberCycleCalculator (Base)          |
//+==================================================================+
class CLaguerreCyberCycleCalculator
  {
protected:
   //--- Composition
   CLaguerreEngine       *m_laguerre_engine;
   CCyberCycleCalculator *m_cyber_engine;

   //--- Internal Buffer
   double            m_filter_buffer[];

   virtual void      CreateEngines(void);

public:
                     CLaguerreCyberCycleCalculator(void);
   virtual          ~CLaguerreCyberCycleCalculator(void);

   //--- Updated Init with Signal params
   bool              Init(double gamma, double cyber_alpha, ENUM_CYBER_SIGNAL_TYPE sig_type, int sig_period, ENUM_MA_TYPE sig_method);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &cycle_out[], double &signal_out[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreCyberCycleCalculator::CLaguerreCyberCycleCalculator(void)
  {
   m_laguerre_engine = NULL;
   m_cyber_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreCyberCycleCalculator::~CLaguerreCyberCycleCalculator(void)
  {
   if(CheckPointer(m_laguerre_engine) != POINTER_INVALID)
      delete m_laguerre_engine;
   if(CheckPointer(m_cyber_engine) != POINTER_INVALID)
      delete m_cyber_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CLaguerreCyberCycleCalculator::CreateEngines(void)
  {
   m_laguerre_engine = new CLaguerreEngine();
   m_cyber_engine = new CCyberCycleCalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreCyberCycleCalculator::Init(double gamma, double cyber_alpha, ENUM_CYBER_SIGNAL_TYPE sig_type, int sig_period, ENUM_MA_TYPE sig_method)
  {
   CreateEngines();

   if(CheckPointer(m_laguerre_engine) == POINTER_INVALID || !m_laguerre_engine.Init(gamma, SOURCE_PRICE))
      return false;

// Pass signal params to Cyber Engine
   if(CheckPointer(m_cyber_engine) == POINTER_INVALID || !m_cyber_engine.Init(cyber_alpha, sig_type, sig_period, sig_method))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CLaguerreCyberCycleCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &cycle_out[], double &signal_out[])
  {
   if(rates_total < 10)
      return;

// Resize internal buffer
   if(ArraySize(m_filter_buffer) != rates_total)
      ArrayResize(m_filter_buffer, rates_total);

// 1. Calculate Standard Laguerre Filter
   m_laguerre_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, m_filter_buffer);

// 2. Calculate Cyber Cycle on the Filter output
   m_cyber_engine.CalculateOnArray(rates_total, prev_calculated, m_filter_buffer, cycle_out, signal_out);
  }

//+==================================================================+
//|           CLASS 2: CLaguerreCyberCycleCalculator_HA              |
//+==================================================================+
class CLaguerreCyberCycleCalculator_HA : public CLaguerreCyberCycleCalculator
  {
protected:
   virtual void      CreateEngines(void) override;
  };

//+------------------------------------------------------------------+
//| Factory Override                                                 |
//+------------------------------------------------------------------+
void CLaguerreCyberCycleCalculator_HA::CreateEngines(void)
  {
   m_laguerre_engine = new CLaguerreEngine_HA();
   m_cyber_engine = new CCyberCycleCalculator();
  }
//+------------------------------------------------------------------+
