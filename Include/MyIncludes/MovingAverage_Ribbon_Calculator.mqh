//+------------------------------------------------------------------+
//|                               MovingAverage_Ribbon_Calculator.mqh|
//|      VERSION 2.01: Corrected method definition placement.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
class CMovingAverageRibbonCalculator
  {
protected:
   CMovingAverageCalculator *m_ma1, *m_ma2, *m_ma3, *m_ma4;
   virtual CMovingAverageCalculator *CreateMAInstance(void);

public:
                     CMovingAverageRibbonCalculator(void);
   virtual          ~CMovingAverageRibbonCalculator(void);

   bool              Init(int p1, ENUM_MA_TYPE t1, int p2, ENUM_MA_TYPE t2,
                          int p3, ENUM_MA_TYPE t3, int p4, ENUM_MA_TYPE t4);

   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &ma1_buffer[], double &ma2_buffer[], double &ma3_buffer[], double &ma4_buffer[]);
  };

//--- Derived class for Heikin Ashi version ---
class CMovingAverageRibbonCalculator_HA : public CMovingAverageRibbonCalculator
  {
protected:
   virtual CMovingAverageCalculator *CreateMAInstance(void) override;
  };

//+==================================================================+
//|         METHOD IMPLEMENTATIONS: CMovingAverageRibbonCalculator   |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMovingAverageRibbonCalculator::CMovingAverageRibbonCalculator(void)
  {
   m_ma1 = NULL;
   m_ma2 = NULL;
   m_ma3 = NULL;
   m_ma4 = NULL;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMovingAverageRibbonCalculator::~CMovingAverageRibbonCalculator(void)
  {
   if(CheckPointer(m_ma1) != POINTER_INVALID)
      delete m_ma1;
   if(CheckPointer(m_ma2) != POINTER_INVALID)
      delete m_ma2;
   if(CheckPointer(m_ma3) != POINTER_INVALID)
      delete m_ma3;
   if(CheckPointer(m_ma4) != POINTER_INVALID)
      delete m_ma4;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMovingAverageCalculator *CMovingAverageRibbonCalculator::CreateMAInstance(void)
  {
   return new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMovingAverageRibbonCalculator::Init(int p1, ENUM_MA_TYPE t1, int p2, ENUM_MA_TYPE t2,
      int p3, ENUM_MA_TYPE t3, int p4, ENUM_MA_TYPE t4)
  {
   m_ma1 = CreateMAInstance();
   m_ma2 = CreateMAInstance();
   m_ma3 = CreateMAInstance();
   m_ma4 = CreateMAInstance();

   if(CheckPointer(m_ma1) == POINTER_INVALID || !m_ma1.Init(p1, t1) ||
      CheckPointer(m_ma2) == POINTER_INVALID || !m_ma2.Init(p2, t2) ||
      CheckPointer(m_ma3) == POINTER_INVALID || !m_ma3.Init(p3, t3) ||
      CheckPointer(m_ma4) == POINTER_INVALID || !m_ma4.Init(p4, t4))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMovingAverageRibbonCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &ma1_buffer[], double &ma2_buffer[], double &ma3_buffer[], double &ma4_buffer[])
  {
   if(CheckPointer(m_ma1) == POINTER_INVALID || CheckPointer(m_ma2) == POINTER_INVALID ||
      CheckPointer(m_ma3) == POINTER_INVALID || CheckPointer(m_ma4) == POINTER_INVALID)
      return;

   m_ma1.Calculate(rates_total, price_type, open, high, low, close, ma1_buffer);
   m_ma2.Calculate(rates_total, price_type, open, high, low, close, ma2_buffer);
   m_ma3.Calculate(rates_total, price_type, open, high, low, close, ma3_buffer);
   m_ma4.Calculate(rates_total, price_type, open, high, low, close, ma4_buffer);
  }

//+==================================================================+
//|       METHOD IMPLEMENTATIONS: CMovingAverageRibbonCalculator_HA  |
//+==================================================================+

//--- CORRECTED: This method definition now belongs to the _HA class ---
CMovingAverageCalculator *CMovingAverageRibbonCalculator_HA::CreateMAInstance(void)
  {
   return new CMovingAverageCalculator_HA();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
