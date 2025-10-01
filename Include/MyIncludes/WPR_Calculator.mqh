//+------------------------------------------------------------------+
//|                                               WPR_Calculator.mqh |
//|      Adapter for the StochasticFast_Calculator to produce WPR.   |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\StochasticFast_Calculator.mqh> // Re-use the Fast Stoch engine

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CWPRCalculator (Base Class)                 |
//|                                                                  |
//+==================================================================+
class CWPRCalculator
  {
protected:
   CStochasticFastCalculator *m_stoch_calculator;

public:
                     CWPRCalculator(void);
   virtual          ~CWPRCalculator(void);

   bool              Init(int wpr_p, int signal_p, ENUM_MA_METHOD signal_ma);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &wpr_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//| CWPRCalculator: Constructor                                      |
//+------------------------------------------------------------------+
CWPRCalculator::CWPRCalculator(void)
  {
   m_stoch_calculator = new CStochasticFastCalculator();
  }

//+------------------------------------------------------------------+
//| CWPRCalculator: Destructor                                       |
//+------------------------------------------------------------------+
CWPRCalculator::~CWPRCalculator(void)
  {
   if(CheckPointer(m_stoch_calculator) != POINTER_INVALID)
      delete m_stoch_calculator;
  }

//+------------------------------------------------------------------+
//| CWPRCalculator: Initialization                                   |
//+------------------------------------------------------------------+
bool CWPRCalculator::Init(int wpr_p, int signal_p, ENUM_MA_METHOD signal_ma)
  {
   if(CheckPointer(m_stoch_calculator) == POINTER_INVALID)
      return false;
// WPR Period is Fast Stoch %K Period, Signal Period is Fast Stoch %D Period
   return m_stoch_calculator.Init(wpr_p, signal_p, signal_ma);
  }

//+------------------------------------------------------------------+
//| CWPRCalculator: Main Calculation Method                          |
//+------------------------------------------------------------------+
void CWPRCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &wpr_buffer[], double &signal_buffer[])
  {
   if(CheckPointer(m_stoch_calculator) == POINTER_INVALID)
      return;

   double k_buffer[], d_buffer[];
   ArrayResize(k_buffer, rates_total);
   ArrayResize(d_buffer, rates_total);

   m_stoch_calculator.Calculate(rates_total, open, high, low, close, k_buffer, d_buffer);

   for(int i = 0; i < rates_total; i++)
     {
      if(k_buffer[i] != EMPTY_VALUE)
         wpr_buffer[i] = k_buffer[i] - 100.0;
      else
         wpr_buffer[i] = EMPTY_VALUE;

      if(d_buffer[i] != EMPTY_VALUE)
         signal_buffer[i] = d_buffer[i] - 100.0;
      else
         signal_buffer[i] = EMPTY_VALUE;
     }
  }

//+==================================================================+
//|                                                                  |
//|           CLASS 2: CWPRCalculator_HA (Heikin Ashi)               |
//|                                                                  |
//+==================================================================+
class CWPRCalculator_HA : public CWPRCalculator
  {
public:
                     CWPRCalculator_HA(void);
  };

//+------------------------------------------------------------------+
//| CWPRCalculator_HA: Constructor                                   |
//+------------------------------------------------------------------+
CWPRCalculator_HA::CWPRCalculator_HA(void)
  {
   if(CheckPointer(m_stoch_calculator) != POINTER_INVALID)
      delete m_stoch_calculator;
   m_stoch_calculator = new CStochasticFastCalculator_HA();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
