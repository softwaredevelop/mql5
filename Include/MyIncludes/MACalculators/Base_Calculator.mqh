//+------------------------------------------------------------------+
//|                                              Base_Calculator.mqh |
//|                 Abstract Base Class for Moving Average Algorithms|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.60"
#property library

#ifndef BASE_CALCULATOR_MQH
#define BASE_CALCULATOR_MQH

//+------------------------------------------------------------------+
//| ABSTRACT BASE CLASS: CBaseMACalculator                           |
//+------------------------------------------------------------------+
class CBaseMACalculator
  {
protected:
   int               m_period;
   double            m_inv_period;

public:
                     CBaseMACalculator(void) : m_period(1), m_inv_period(1.0) {}
   virtual          ~CBaseMACalculator(void) {}

   virtual bool      Init(const int period)
     {
      m_period     = (period < 1) ? 1 : period;
      m_inv_period = 1.0 / (double)m_period;
      return true;
     }

   virtual void      Calculate(const int rates_total,
                               const int start_index,
                               const double &price[],
                               const double &volume[],
                               double &output[],
                               const int data_offset = 0) = 0;

   virtual int       GetWarmupBars(void) const { return m_period - 1; }
  };

#endif // BASE_CALCULATOR_MQH
//+------------------------------------------------------------------+