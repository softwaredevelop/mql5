//+------------------------------------------------------------------+
//|                                      StochRSI_Slow_Calculator.mqh|
//|  VERSION 2.00: Uses MovingAverage_Engine for smoothing.          |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\RSI_Pro_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|           CLASS: CStochRSI_Slow_Calculator                       |
//+==================================================================+
class CStochRSI_Slow_Calculator
  {
protected:
   int               m_rsi_period, m_k_period;

   //--- Composition: RSI Engine + 2 MA Engines
   CRSIProCalculator *m_rsi_calculator;
   CMovingAverageCalculator m_slowing_engine; // For Slow %K
   CMovingAverageCalculator m_signal_engine;  // For %D

   //--- Persistent Buffers
   double            m_rsi_buffer[];
   double            m_raw_k[];

   double            Highest(const double &array[], int period, int current_pos);
   double            Lowest(const double &array[], int period, int current_pos);

public:
                     CStochRSI_Slow_Calculator(void);
   virtual          ~CStochRSI_Slow_Calculator(void);

   //--- Init now takes ENUM_MA_TYPE for both smoothings
   bool              Init(int rsi_p, int k_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStochRSI_Slow_Calculator::CStochRSI_Slow_Calculator(void)
  {
   m_rsi_calculator = new CRSIProCalculator();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStochRSI_Slow_Calculator::~CStochRSI_Slow_Calculator(void)
  {
   if(CheckPointer(m_rsi_calculator) != POINTER_INVALID)
      delete m_rsi_calculator;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochRSI_Slow_Calculator::Init(int rsi_p, int k_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma)
  {
   m_rsi_period = (rsi_p < 1) ? 1 : rsi_p;
   m_k_period   = (k_p < 1) ? 1 : k_p;

   if(CheckPointer(m_rsi_calculator) == POINTER_INVALID)
      return false;

// Init RSI calculator
   if(!m_rsi_calculator.Init(m_rsi_period, 1, MODE_SMA, 2.0))
      return false;

// Init MA Engines
   if(!m_slowing_engine.Init(slow_p, slow_ma))
      return false;
   if(!m_signal_engine.Init(d_p, d_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CStochRSI_Slow_Calculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &k_buffer[], double &d_buffer[])
  {
// Minimum bars check
   int min_bars = m_rsi_period + m_k_period + m_slowing_engine.GetPeriod() + m_signal_engine.GetPeriod();
   if(rates_total <= min_bars)
      return;

   if(CheckPointer(m_rsi_calculator) == POINTER_INVALID)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_rsi_buffer) != rates_total)
     {
      ArrayResize(m_rsi_buffer, rates_total);
      ArrayResize(m_raw_k, rates_total);
     }

//--- 1. Calculate RSI (Incremental)
   double dummy1[], dummy2[], dummy3[];
   m_rsi_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                              m_rsi_buffer, dummy1, dummy2, dummy3);

//--- 2. Calculate Raw %K (Fast %K)
// RSI valid from: m_rsi_period
// Raw %K valid from: m_rsi_period + m_k_period - 1
   int raw_k_offset = m_rsi_period + m_k_period - 1;
   int loop_start_k = MathMax(raw_k_offset, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      double highest_rsi = Highest(m_rsi_buffer, m_k_period, i);
      double lowest_rsi  = Lowest(m_rsi_buffer, m_k_period, i);
      double range = highest_rsi - lowest_rsi;

      if(range > 0.00001)
         m_raw_k[i] = (m_rsi_buffer[i] - lowest_rsi) / range * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i-1] : 50.0;
     }

//--- 3. Calculate Slow %K (Main Line) using Slowing Engine
// Input: m_raw_k
// Output: k_buffer
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, k_buffer, raw_k_offset);

//--- 4. Calculate %D (Signal Line) using Signal Engine
// Slow %K valid from: raw_k_offset + slowing_period - 1
   int slow_k_offset = raw_k_offset + m_slowing_engine.GetPeriod() - 1;

// Input: k_buffer
// Output: d_buffer
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, slow_k_offset);
  }

//+------------------------------------------------------------------+
//| Highest                                                          |
//+------------------------------------------------------------------+
double CStochRSI_Slow_Calculator::Highest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res < array[index])
         res = array[index];
     }
   return(res);
  }

//+------------------------------------------------------------------+
//| Lowest                                                           |
//+------------------------------------------------------------------+
double CStochRSI_Slow_Calculator::Lowest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res > array[index])
         res = array[index];
     }
   return(res);
  }

//+==================================================================+
//|         CLASS 2: CStochRSI_Slow_Calculator_HA (Heikin Ashi)      |
//+==================================================================+
class CStochRSI_Slow_Calculator_HA : public CStochRSI_Slow_Calculator
  {
public:
                     CStochRSI_Slow_Calculator_HA(void);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStochRSI_Slow_Calculator_HA::CStochRSI_Slow_Calculator_HA(void)
  {
   if(CheckPointer(m_rsi_calculator) != POINTER_INVALID)
      delete m_rsi_calculator;
   m_rsi_calculator = new CRSIProCalculator_HA();
  }
//+------------------------------------------------------------------+
