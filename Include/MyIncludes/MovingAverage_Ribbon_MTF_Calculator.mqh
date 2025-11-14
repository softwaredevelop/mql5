//+------------------------------------------------------------------+
//|                           MovingAverage_Ribbon_MTF_Calculator.mqh|
//|      Engine for the fully customizable MTF MA Ribbon.            |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Single_MA_MTF_Calculator.mqh>

//+==================================================================+
class CMovingAverageRibbonMTFCalculator
  {
protected:
   //--- Composition: The Ribbon HAS four single MTF MA calculators
   CSingleMAMTFCalculator *m_ma1, *m_ma2, *m_ma3, *m_ma4;

public:
                     CMovingAverageRibbonMTFCalculator(void);
   virtual          ~CMovingAverageRibbonMTFCalculator(void);

   bool              Init(ENUM_TIMEFRAMES tf1, int p1, ENUM_MA_TYPE t1,
                          ENUM_TIMEFRAMES tf2, int p2, ENUM_MA_TYPE t2,
                          ENUM_TIMEFRAMES tf3, int p3, ENUM_MA_TYPE t3,
                          ENUM_TIMEFRAMES tf4, int p4, ENUM_MA_TYPE t4,
                          bool is_ha);

   void              Calculate(int rates_total, const datetime &time[], ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &ma1_buffer[], double &ma2_buffer[], double &ma3_buffer[], double &ma4_buffer[]);
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMovingAverageRibbonMTFCalculator::CMovingAverageRibbonMTFCalculator(void)
  {
   m_ma1 = NULL;
   m_ma2 = NULL;
   m_ma3 = NULL;
   m_ma4 = NULL;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMovingAverageRibbonMTFCalculator::~CMovingAverageRibbonMTFCalculator(void)
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
bool CMovingAverageRibbonMTFCalculator::Init(ENUM_TIMEFRAMES tf1, int p1, ENUM_MA_TYPE t1,
      ENUM_TIMEFRAMES tf2, int p2, ENUM_MA_TYPE t2,
      ENUM_TIMEFRAMES tf3, int p3, ENUM_MA_TYPE t3,
      ENUM_TIMEFRAMES tf4, int p4, ENUM_MA_TYPE t4,
      bool is_ha)
  {
   m_ma1 = new CSingleMAMTFCalculator();
   m_ma2 = new CSingleMAMTFCalculator();
   m_ma3 = new CSingleMAMTFCalculator();
   m_ma4 = new CSingleMAMTFCalculator();

   if(CheckPointer(m_ma1) == POINTER_INVALID || !m_ma1.Init(tf1, p1, t1, is_ha) ||
      CheckPointer(m_ma2) == POINTER_INVALID || !m_ma2.Init(tf2, p2, t2, is_ha) ||
      CheckPointer(m_ma3) == POINTER_INVALID || !m_ma3.Init(tf3, p3, t3, is_ha) ||
      CheckPointer(m_ma4) == POINTER_INVALID || !m_ma4.Init(tf4, p4, t4, is_ha))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMovingAverageRibbonMTFCalculator::Calculate(int rates_total, const datetime &time[], ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &ma1_buffer[], double &ma2_buffer[], double &ma3_buffer[], double &ma4_buffer[])
  {
   if(CheckPointer(m_ma1) == POINTER_INVALID || CheckPointer(m_ma2) == POINTER_INVALID ||
      CheckPointer(m_ma3) == POINTER_INVALID || CheckPointer(m_ma4) == POINTER_INVALID)
      return;

   m_ma1.Calculate(rates_total, time, price_type, open, high, low, close, ma1_buffer);
   m_ma2.Calculate(rates_total, time, price_type, open, high, low, close, ma2_buffer);
   m_ma3.Calculate(rates_total, time, price_type, open, high, low, close, ma3_buffer);
   m_ma4.Calculate(rates_total, time, price_type, open, high, low, close, ma4_buffer);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
