//+------------------------------------------------------------------+
//|                               MACD_SuperSmoother_Calculator.mqh  |
//|         VERSION 1.10: Corrected access modifiers and state mgmt. |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>

//+==================================================================+
class CMACDSuperSmootherCalculator
  {
protected:
   //--- Periods
   int               m_fast_period, m_slow_period, m_signal_period;

   //--- Internal calculators (Composition)
   CEhlersSmootherCalculator *m_fast_smoother;
   CEhlersSmootherCalculator *m_slow_smoother;

   //--- State for the signal line smoother (CRITICAL FIX)
   double            m_sig_f1, m_sig_f2;

   virtual CEhlersSmootherCalculator *CreateSmootherInstance(void);

public:
                     CMACDSuperSmootherCalculator(void);
   virtual          ~CMACDSuperSmootherCalculator(void);

   bool              Init(int fast_p, int slow_p, int signal_p);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &macd_line[], double &signal_line[], double &histogram[]);
  };

//--- Derived class for Heikin Ashi version ---
class CMACDSuperSmootherCalculator_HA : public CMACDSuperSmootherCalculator
  {
protected:
   virtual CEhlersSmootherCalculator *CreateSmootherInstance(void) override;
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMACDSuperSmootherCalculator::CMACDSuperSmootherCalculator(void)
  {
   m_fast_smoother = NULL;
   m_slow_smoother = NULL;
   m_sig_f1 = 0;
   m_sig_f2 = 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMACDSuperSmootherCalculator::~CMACDSuperSmootherCalculator(void)
  {
   if(CheckPointer(m_fast_smoother) != POINTER_INVALID)
      delete m_fast_smoother;
   if(CheckPointer(m_slow_smoother) != POINTER_INVALID)
      delete m_slow_smoother;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CEhlersSmootherCalculator *CMACDSuperSmootherCalculator::CreateSmootherInstance(void) { return new CEhlersSmootherCalculator(); }
CEhlersSmootherCalculator *CMACDSuperSmootherCalculator_HA::CreateSmootherInstance(void) { return new CEhlersSmootherCalculator_HA(); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMACDSuperSmootherCalculator::Init(int fast_p, int slow_p, int signal_p)
  {
   if(fast_p > slow_p)
     {
      int temp=fast_p;
      fast_p=slow_p;
      slow_p=temp;
     }

//--- Store periods as member variables
   m_fast_period = fast_p;
   m_slow_period = slow_p;
   m_signal_period = signal_p;

//--- Reset signal line state
   m_sig_f1 = 0;
   m_sig_f2 = 0;

   m_fast_smoother = CreateSmootherInstance();
   m_slow_smoother = CreateSmootherInstance();

   if(CheckPointer(m_fast_smoother) == POINTER_INVALID || !m_fast_smoother.Init(m_fast_period, SUPERSMOOTHER, SOURCE_PRICE) ||
      CheckPointer(m_slow_smoother) == POINTER_INVALID || !m_slow_smoother.Init(m_slow_period, SUPERSMOOTHER, SOURCE_PRICE))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMACDSuperSmootherCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &macd_line[], double &signal_line[], double &histogram[])
  {
//--- CORRECTED: Use member variables for period check
   if(rates_total <= m_slow_period + m_signal_period)
      return;

   double fast_buffer[], slow_buffer[];
   ArrayResize(fast_buffer, rates_total, 0);
   ArrayResize(slow_buffer, rates_total, 0);

   m_fast_smoother.Calculate(rates_total, price_type, open, high, low, close, fast_buffer);
   m_slow_smoother.Calculate(rates_total, price_type, open, high, low, close, slow_buffer);

   for(int i = 0; i < rates_total; i++)
      macd_line[i] = fast_buffer[i] - slow_buffer[i];

//--- STEP 4: Calculate Signal Line (SuperSmoother on MACD Line) with proper state management
//--- CORRECTED: Use GetPeriod() and member variables
   double a1 = exp(-M_SQRT2 * M_PI / m_signal_period);
   double b1 = 2.0 * a1 * cos(M_SQRT2 * M_PI / m_signal_period);
   double c2 = b1, c3 = -a1*a1, c1 = 1.0 - c2 - c3;

//--- Robust initialization
   if(ArraySize(signal_line) == 0 || signal_line[0] == 0)
     {
      if(rates_total > 0)
         signal_line[0] = macd_line[0];
      if(rates_total > 1)
         signal_line[1] = macd_line[1];
      m_sig_f2 = signal_line[0];
      m_sig_f1 = signal_line[1];
     }

   for(int i=2; i<rates_total; i++)
     {
      signal_line[i] = c1 * (macd_line[i] + macd_line[i-1]) / 2.0 + c2 * m_sig_f1 + c3 * m_sig_f2;
      m_sig_f2 = m_sig_f1;
      m_sig_f1 = signal_line[i];
     }

   for(int i = 0; i < rates_total; i++)
      histogram[i] = macd_line[i] - signal_line[i];
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
