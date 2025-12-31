//+------------------------------------------------------------------+
//|                                               CHO_Calculator.mqh |
//|         Calculation engine for Standard and Heikin Ashi CHO.     |
//|      VERSION 3.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\AD_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|             CLASS 1: CCHOCalculator (Base Class)                 |
//+==================================================================+
class CCHOCalculator
  {
protected:
   int               m_fast_period;
   int               m_slow_period;

   //--- Composition: AD Calculator + 2 MA Engines
   CADCalculator     *m_ad_calculator;
   CMovingAverageCalculator m_fast_ma_engine;
   CMovingAverageCalculator m_slow_ma_engine;

   //--- Persistent Buffers for Incremental Calculation
   double            m_adl_buffer[];
   double            m_fast_ma_buffer[];
   double            m_slow_ma_buffer[];

public:
                     CCHOCalculator(void);
   virtual          ~CCHOCalculator(void);

   //--- Init now takes ENUM_MA_TYPE
   bool              Init(int fast_p, int slow_p, ENUM_MA_TYPE ma_m, ENUM_APPLIED_VOLUME vol_t);
   int               GetSlowPeriod(void) const { return m_slow_period; }

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], ENUM_APPLIED_VOLUME volume_type, double &cho_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CCHOCalculator::CCHOCalculator(void)
  {
   m_ad_calculator = new CADCalculator();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CCHOCalculator::~CCHOCalculator(void)
  {
   if(CheckPointer(m_ad_calculator) != POINTER_INVALID)
      delete m_ad_calculator;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CCHOCalculator::Init(int fast_p, int slow_p, ENUM_MA_TYPE ma_m, ENUM_APPLIED_VOLUME vol_t)
  {
   m_fast_period = (fast_p < 1) ? 1 : fast_p;
   m_slow_period = (slow_p < 1) ? 1 : slow_p;

   if(m_fast_period > m_slow_period)
     {
      int temp = m_fast_period;
      m_fast_period = m_slow_period;
      m_slow_period = temp;
     }

// Initialize MA Engines
   if(!m_fast_ma_engine.Init(m_fast_period, ma_m))
      return false;
   if(!m_slow_ma_engine.Init(m_slow_period, ma_m))
      return false;

   return (CheckPointer(m_ad_calculator) != POINTER_INVALID);
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CCHOCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], ENUM_APPLIED_VOLUME volume_type, double &cho_buffer[])
  {
   if(rates_total < m_slow_period || CheckPointer(m_ad_calculator) == POINTER_INVALID)
      return;

// Resize internal buffers
   if(ArraySize(m_adl_buffer) != rates_total)
     {
      ArrayResize(m_adl_buffer, rates_total);
      ArrayResize(m_fast_ma_buffer, rates_total);
      ArrayResize(m_slow_ma_buffer, rates_total);
     }

//--- 1. Calculate ADL (Incremental)
// The AD calculator handles its own incremental logic
   m_ad_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, tick_volume, volume, volume_type, m_adl_buffer);

//--- 2. Calculate Fast MA on ADL (Using Engine)
// ADL is valid from index 0
   m_fast_ma_engine.CalculateOnArray(rates_total, prev_calculated, m_adl_buffer, m_fast_ma_buffer, 0);

//--- 3. Calculate Slow MA on ADL (Using Engine)
   m_slow_ma_engine.CalculateOnArray(rates_total, prev_calculated, m_adl_buffer, m_slow_ma_buffer, 0);

//--- 4. Calculate CHO (Fast - Slow)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int loop_start = MathMax(m_slow_period - 1, start_index);

   if(prev_calculated == 0)
      ArrayInitialize(cho_buffer, EMPTY_VALUE);

   for(int i = loop_start; i < rates_total; i++)
     {
      if(m_fast_ma_buffer[i] != EMPTY_VALUE && m_slow_ma_buffer[i] != EMPTY_VALUE)
         cho_buffer[i] = m_fast_ma_buffer[i] - m_slow_ma_buffer[i];
      else
         cho_buffer[i] = EMPTY_VALUE;
     }
  }

//+==================================================================+
//|             CLASS 2: CCHOCalculator_HA (Heikin Ashi)             |
//+==================================================================+
class CCHOCalculator_HA : public CCHOCalculator
  {
public:
                     CCHOCalculator_HA(void);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CCHOCalculator_HA::CCHOCalculator_HA(void)
  {
   if(CheckPointer(m_ad_calculator) != POINTER_INVALID)
      delete m_ad_calculator;
// Use HA version of AD calculator
   m_ad_calculator = new CADCalculator_HA();
  }

//+==================================================================+
//|             CLASS 3: CCHOCalculator_Std (Standard)               |
//+==================================================================+
class CCHOCalculator_Std : public CCHOCalculator
  {
  };
//+------------------------------------------------------------------+
