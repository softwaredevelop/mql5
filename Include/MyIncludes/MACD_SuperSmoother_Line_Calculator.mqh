//+------------------------------------------------------------------+
//|                           MACD_SuperSmoother_Line_Calculator.mqh |
//|         Engine for calculating only the MACD Line with SS.       |
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

   virtual CEhlersSmootherCalculator *CreateSmootherInstance(void);

public:
                     CMACDSuperSmootherLineCalculator(void);
   virtual          ~CMACDSuperSmootherLineCalculator(void);

   bool              Init(int fast_p, int slow_p);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
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
//|                                                                  |
//+------------------------------------------------------------------+
CMACDSuperSmootherLineCalculator::CMACDSuperSmootherLineCalculator(void)
  {
   m_fast_smoother = NULL;
   m_slow_smoother = NULL;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMACDSuperSmootherLineCalculator::~CMACDSuperSmootherLineCalculator(void)
  {
   if(CheckPointer(m_fast_smoother) != POINTER_INVALID)
      delete m_fast_smoother;
   if(CheckPointer(m_slow_smoother) != POINTER_INVALID)
      delete m_slow_smoother;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CEhlersSmootherCalculator *CMACDSuperSmootherLineCalculator::CreateSmootherInstance(void) { return new CEhlersSmootherCalculator(); }
CEhlersSmootherCalculator *CMACDSuperSmootherLineCalculator_HA::CreateSmootherInstance(void) { return new CEhlersSmootherCalculator_HA(); }

//+------------------------------------------------------------------+
//|                                                                  |
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
//|                                                                  |
//+------------------------------------------------------------------+
void CMACDSuperSmootherLineCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &macd_line[])
  {
   if(rates_total <= m_slow_period)
      return;

   double fast_buffer[], slow_buffer[];
   ArrayResize(fast_buffer, rates_total, 0);
   ArrayResize(slow_buffer, rates_total, 0);

   m_fast_smoother.Calculate(rates_total, price_type, open, high, low, close, fast_buffer);
   m_slow_smoother.Calculate(rates_total, price_type, open, high, low, close, slow_buffer);

   for(int i = 0; i < rates_total; i++)
      macd_line[i] = fast_buffer[i] - slow_buffer[i];
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
