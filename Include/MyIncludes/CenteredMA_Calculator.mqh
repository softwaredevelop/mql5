//+------------------------------------------------------------------+
//|                                        CenteredMA_Calculator.mqh |
//|      Engine for calculating a Centered Moving Average (CMA).     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
class CCenteredMACalculator
  {
protected:
   int               m_period;
   CMovingAverageCalculator *m_ma_calc;

public:
                     CCenteredMACalculator(void);
   virtual          ~CCenteredMACalculator(void);

   bool              Init(int period, ENUM_MA_TYPE ma_type);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &cma_buffer[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CCenteredMACalculator_HA : public CCenteredMACalculator
  {
public:
                     CCenteredMACalculator_HA(void);
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CCenteredMACalculator::CCenteredMACalculator(void) { m_ma_calc = new CMovingAverageCalculator(); }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CCenteredMACalculator::~CCenteredMACalculator(void) { if(CheckPointer(m_ma_calc) != POINTER_INVALID) delete m_ma_calc; }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CCenteredMACalculator_HA::CCenteredMACalculator_HA(void)
  {
   if(CheckPointer(m_ma_calc) != POINTER_INVALID)
      delete m_ma_calc;
   m_ma_calc = new CMovingAverageCalculator_HA();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CCenteredMACalculator::Init(int period, ENUM_MA_TYPE ma_type)
  {
   m_period = period;
   if(CheckPointer(m_ma_calc) == POINTER_INVALID)
      return false;
   return m_ma_calc.Init(period, ma_type);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CCenteredMACalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                      double &cma_buffer[])
  {
   if(rates_total < m_period)
      return;
   if(CheckPointer(m_ma_calc) == POINTER_INVALID)
      return;

//--- Step 1: Calculate the standard, lagging MA into an internal buffer ---
   double ma_buffer[];
   ArrayResize(ma_buffer, rates_total);
   m_ma_calc.Calculate(rates_total, price_type, open, high, low, close, ma_buffer);

//--- Step 2: Shift the MA backwards in time to center it ---
   int shift = (m_period - 1) / 2;

   for(int i = 0; i < rates_total; i++)
     {
      int source_index = i + shift;
      if(source_index < rates_total)
         cma_buffer[i] = ma_buffer[source_index];
      else
         cma_buffer[i] = EMPTY_VALUE; // No data available for the future part
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
