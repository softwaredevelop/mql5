//+------------------------------------------------------------------+
//|                                 Stochastic_CMO_Slow_Calculator.mqh |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\CMO_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|           CLASS: CStochasticCMOSlowCalculator                    |
//+==================================================================+
class CStochasticCMOSlowCalculator
  {
protected:
   int               m_cmo_period, m_k_period;

   //--- Engines
   CCMOCalculator    *m_cmo_calculator;
   CMovingAverageCalculator m_slowing_engine;
   CMovingAverageCalculator m_signal_engine;

   //--- Persistent Buffers
   double            m_cmo_buffer[];
   double            m_raw_k[];

   double            Highest(const double &array[], int period, int current_pos);
   double            Lowest(const double &array[], int period, int current_pos);

   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

public:
                     CStochasticCMOSlowCalculator(void);
   virtual          ~CStochasticCMOSlowCalculator(void);

   //--- Init now takes ENUM_MA_TYPE for both smoothings
   bool              Init(int cmo_p, int k_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStochasticCMOSlowCalculator::CStochasticCMOSlowCalculator(void)
  {
   m_cmo_calculator = new CCMOCalculator();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStochasticCMOSlowCalculator::~CStochasticCMOSlowCalculator(void)
  {
   if(CheckPointer(m_cmo_calculator) != POINTER_INVALID)
      delete m_cmo_calculator;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochasticCMOSlowCalculator::Init(int cmo_p, int k_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma)
  {
   m_cmo_period = (cmo_p < 1) ? 1 : cmo_p;
   m_k_period   = (k_p < 1) ? 1 : k_p;

   if(CheckPointer(m_cmo_calculator) == POINTER_INVALID)
      return false;
   if(!m_cmo_calculator.Init(m_cmo_period))
      return false;

   if(!m_slowing_engine.Init(slow_p, slow_ma))
      return false;
   if(!m_signal_engine.Init(d_p, d_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CStochasticCMOSlowCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &k_buffer[], double &d_buffer[])
  {
// Minimum bars check
   int min_bars = m_cmo_period + m_k_period + m_slowing_engine.GetPeriod() + m_signal_engine.GetPeriod();
   if(rates_total <= min_bars)
      return;

   if(CheckPointer(m_cmo_calculator) == POINTER_INVALID)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_cmo_buffer) != rates_total)
     {
      ArrayResize(m_cmo_buffer, rates_total);
      ArrayResize(m_raw_k, rates_total);
     }

   if(!PrepareSourceData(rates_total, start_index, open, high, low, close, price_type))
      return;

//--- 1. Calculate CMO (Incremental)
// Note: CMO Calculator handles its own incremental logic
   m_cmo_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_cmo_buffer);

//--- 2. Calculate Raw %K (Fast %K) on CMO
// CMO valid from: m_cmo_period
// Raw %K valid from: m_cmo_period + m_k_period - 1
   int raw_k_start = m_cmo_period + m_k_period - 1;
   int loop_start_k = MathMax(raw_k_start, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      double highest_cmo = Highest(m_cmo_buffer, m_k_period, i);
      double lowest_cmo  = Lowest(m_cmo_buffer, m_k_period, i);
      double range = highest_cmo - lowest_cmo;

      if(range > 0.00001)
         m_raw_k[i] = (m_cmo_buffer[i] - lowest_cmo) / range * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i-1] : 50.0;
     }

//--- 3. Calculate Slow %K (Main Line) using Slowing Engine
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, k_buffer, raw_k_start);

//--- 4. Calculate %D (Signal Line) using Signal Engine
   int d_offset = raw_k_start + m_slowing_engine.GetPeriod() - 1;
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, d_offset);
  }

//+------------------------------------------------------------------+
//| Highest                                                          |
//+------------------------------------------------------------------+
double CStochasticCMOSlowCalculator::Highest(const double &array[], int period, int current_pos)
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
double CStochasticCMOSlowCalculator::Lowest(const double &array[], int period, int current_pos)
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

//+------------------------------------------------------------------+
//| Prepare Source Data (Standard)                                   |
//+------------------------------------------------------------------+
bool CStochasticCMOSlowCalculator::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
// This method is just a placeholder for the base class.
// The CMO calculator handles its own data preparation internally.
   return true;
  }

//+==================================================================+
//|             CLASS 2: CStochasticCMOSlowCalculator_HA             |
//+==================================================================+
class CStochasticCMOSlowCalculator_HA : public CStochasticCMOSlowCalculator
  {
public:
                     CStochasticCMOSlowCalculator_HA(void);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStochasticCMOSlowCalculator_HA::CStochasticCMOSlowCalculator_HA(void)
  {
   if(CheckPointer(m_cmo_calculator) != POINTER_INVALID)
      delete m_cmo_calculator;
// Use HA version of CMO calculator
   m_cmo_calculator = new CCMOCalculator_HA();
  }
//+------------------------------------------------------------------+
