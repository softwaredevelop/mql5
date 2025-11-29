//+------------------------------------------------------------------+
//|                           MACD_SuperSmoother_Line_Calculator.mqh |
//|      VERSION 1.20: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>

//+==================================================================+
class CMACDSuperSmootherLineCalculator
  {
protected:
   int               m_fast_period, m_slow_period;
   CEhlersSmootherCalculator *m_fast_smoother;
   CEhlersSmootherCalculator *m_slow_smoother;

   //--- Persistent buffers for recursive state
   double            m_fast_buffer[];
   double            m_slow_buffer[];

   virtual CEhlersSmootherCalculator *CreateSmootherInstance(void);

public:
                     CMACDSuperSmootherLineCalculator(void);
   virtual          ~CMACDSuperSmootherLineCalculator(void);

   bool              Init(int fast_p, int slow_p);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &macd_line[]);
  };

//--- Derived class for Heikin Ashi version ---
class CMACDSuperSmootherLineCalculator_HA : public CMACDSuperSmootherLineCalculator
  {
protected:
   virtual CEhlersSmootherCalculator *CreateSmootherInstance(void) override;
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMACDSuperSmootherLineCalculator::CMACDSuperSmootherLineCalculator(void)
  {
   m_fast_smoother = NULL;
   m_slow_smoother = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMACDSuperSmootherLineCalculator::~CMACDSuperSmootherLineCalculator(void)
  {
   if(CheckPointer(m_fast_smoother) != POINTER_INVALID)
      delete m_fast_smoother;
   if(CheckPointer(m_slow_smoother) != POINTER_INVALID)
      delete m_slow_smoother;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
CEhlersSmootherCalculator *CMACDSuperSmootherLineCalculator::CreateSmootherInstance(void) { return new CEhlersSmootherCalculator(); }
CEhlersSmootherCalculator *CMACDSuperSmootherLineCalculator_HA::CreateSmootherInstance(void) { return new CEhlersSmootherCalculator_HA(); }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMACDSuperSmootherLineCalculator::Init(int fast_p, int slow_p)
  {
   if(fast_p > slow_p)
     {
      int temp=fast_p;
      fast_p=slow_p;
      slow_p=temp;
     }

   m_fast_period = fast_p;
   m_slow_period = slow_p;

   m_fast_smoother = CreateSmootherInstance();
   m_slow_smoother = CreateSmootherInstance();

   if(CheckPointer(m_fast_smoother) == POINTER_INVALID || !m_fast_smoother.Init(m_fast_period, SUPERSMOOTHER, SOURCE_PRICE) ||
      CheckPointer(m_slow_smoother) == POINTER_INVALID || !m_slow_smoother.Init(m_slow_period, SUPERSMOOTHER, SOURCE_PRICE))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CMACDSuperSmootherLineCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &macd_line[])
  {
   if(rates_total <= m_slow_period)
      return;

//--- Resize persistent buffers
   if(ArraySize(m_fast_buffer) != rates_total)
      ArrayResize(m_fast_buffer, rates_total);
   if(ArraySize(m_slow_buffer) != rates_total)
      ArrayResize(m_slow_buffer, rates_total);

//--- Calculate Smoothers (Incremental)
   m_fast_smoother.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_fast_buffer);
   m_slow_smoother.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_slow_buffer);

//--- Calculate MACD Line
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start_index; i < rates_total; i++)
      macd_line[i] = m_fast_buffer[i] - m_slow_buffer[i];
  }
//+------------------------------------------------------------------+
