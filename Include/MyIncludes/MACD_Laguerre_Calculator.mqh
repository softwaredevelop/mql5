//+------------------------------------------------------------------+
//|                                     MACD_Laguerre_Calculator.mqh |
//|         Engine for the full MACD calculated from Laguerre.       |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Laguerre_Engine.mqh>

//+==================================================================+
class CMACDLaguerreCalculator
  {
protected:
   double            m_fast_gamma, m_slow_gamma, m_signal_gamma;
   CLaguerreEngine   *m_fast_engine;
   CLaguerreEngine   *m_slow_engine;

   //--- State variables for the signal line's Laguerre filter
   double            m_sig_L0_prev, m_sig_L1_prev, m_sig_L2_prev, m_sig_L3_prev;

   virtual CLaguerreEngine *CreateEngineInstance(void);

public:
                     CMACDLaguerreCalculator(void);
   virtual          ~CMACDLaguerreCalculator(void);

   bool              Init(double gamma1, double gamma2, double signal_g);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &macd_line[], double &signal_line[], double &histogram[]);
  };

//--- Derived class for Heikin Ashi version ---
class CMACDLaguerreCalculator_HA : public CMACDLaguerreCalculator
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
CMACDLaguerreCalculator::CMACDLaguerreCalculator(void)
  {
   m_fast_engine = NULL;
   m_slow_engine = NULL;
   m_sig_L0_prev = 0;
   m_sig_L1_prev = 0;
   m_sig_L2_prev = 0;
   m_sig_L3_prev = 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMACDLaguerreCalculator::~CMACDLaguerreCalculator(void)
  {
   if(CheckPointer(m_fast_engine) != POINTER_INVALID)
      delete m_fast_engine;
   if(CheckPointer(m_slow_engine) != POINTER_INVALID)
      delete m_slow_engine;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CLaguerreEngine *CMACDLaguerreCalculator::CreateEngineInstance(void) { return new CLaguerreEngine(); }
CLaguerreEngine *CMACDLaguerreCalculator_HA::CreateEngineInstance(void) { return new CLaguerreEngine_HA(); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMACDLaguerreCalculator::Init(double gamma1, double gamma2, double signal_g)
  {
   m_fast_gamma = MathMin(gamma1, gamma2);
   m_slow_gamma = MathMax(gamma1, gamma2);
   m_signal_gamma = fmax(0.0, fmin(1.0, signal_g));

// Reset state
   m_sig_L0_prev = 0;
   m_sig_L1_prev = 0;
   m_sig_L2_prev = 0;
   m_sig_L3_prev = 0;

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
void CMACDLaguerreCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                                        double &macd_line[], double &signal_line[], double &histogram[])
  {
   if(rates_total < 2)
      return;

   double fast_filter[], slow_filter[];
   double L0_dummy[], L1_dummy[], L2_dummy[], L3_dummy[];

   m_fast_engine.CalculateFilter(rates_total, price_type, open, high, low, close, L0_dummy, L1_dummy, L2_dummy, L3_dummy, fast_filter);
   m_slow_engine.CalculateFilter(rates_total, price_type, open, high, low, close, L0_dummy, L1_dummy, L2_dummy, L3_dummy, slow_filter);

   for(int i = 0; i < rates_total; i++)
      macd_line[i] = fast_filter[i] - slow_filter[i];

//--- STEP 4: Calculate Signal Line (Laguerre Filter on MACD Line)
// Robust initialization
   if(rates_total > 0)
     {
      signal_line[0] = macd_line[0];
      m_sig_L0_prev = macd_line[0];
      m_sig_L1_prev = macd_line[0];
      m_sig_L2_prev = macd_line[0];
      m_sig_L3_prev = macd_line[0];
     }

   for(int i = 1; i < rates_total; i++)
     {
      double L0 = (1.0 - m_signal_gamma) * macd_line[i] + m_signal_gamma * m_sig_L0_prev;
      double L1 = -m_signal_gamma * L0 + m_sig_L0_prev + m_signal_gamma * m_sig_L1_prev;
      double L2 = -m_signal_gamma * L1 + m_sig_L1_prev + m_signal_gamma * m_sig_L2_prev;
      double L3 = -m_signal_gamma * L2 + m_sig_L2_prev + m_signal_gamma * m_sig_L3_prev;

      signal_line[i] = (L0 + 2.0 * L1 + 2.0 * L2 + L3) / 6.0;

      m_sig_L0_prev = L0;
      m_sig_L1_prev = L1;
      m_sig_L2_prev = L2;
      m_sig_L3_prev = L3;
     }

//--- STEP 5: Calculate Histogram
   for(int i = 0; i < rates_total; i++)
      histogram[i] = macd_line[i] - signal_line[i];
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
