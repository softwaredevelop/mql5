//+------------------------------------------------------------------+
//|                                     StochasticSlow_Calculator.mqh|
//|                     VERSION 2.20: Direct In-Place HA Math Engine |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.20" // Enterprise Refactor: In-Place Heikin Ashi Mapping & Zero Redundancy
#property description "High-performance calculation engine for Slow Stochastic Oscillator."

#ifndef STOCHASTIC_SLOW_CALCULATOR_MQH
#define STOCHASTIC_SLOW_CALCULATOR_MQH

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|           CLASS: CStochasticSlowCalculator                       |
//+==================================================================+
class CStochasticSlowCalculator
  {
protected:
   int                      m_k_period;

   //--- Composition: Two Embedded MA Engines (Zero Heap Overhead!)
   CMovingAverageCalculator m_slowing_engine; // For Slow %K
   CMovingAverageCalculator m_signal_engine;  // For %D

   //--- Persistent Buffers
   double                   m_src_high[], m_src_low[], m_src_close[];
   double                   m_raw_k[]; // Stores Fast %K (intermediate)

   double                   Highest(int period, int current_pos);
   double                   Lowest(int period, int current_pos);

   virtual bool             PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CStochasticSlowCalculator(void) : m_k_period(5) {};
   virtual                 ~CStochasticSlowCalculator(void) {};

   bool                     Init(int k_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma);

   void                     Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                                      double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochasticSlowCalculator::Init(int k_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma)
  {
   m_k_period = (k_p < 1) ? 1 : k_p;

   if(!m_slowing_engine.Init(slow_p, slow_ma))
      return false;
   if(!m_signal_engine.Init(d_p, d_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Incremental O(1))                              |
//+------------------------------------------------------------------+
void CStochasticSlowCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
   int min_bars = m_k_period + m_slowing_engine.GetPeriod() + m_signal_engine.GetPeriod();
   if(rates_total <= min_bars)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize state buffers
   if(ArraySize(m_src_high) != rates_total)
     {
      ArrayResize(m_src_high,  rates_total);
      ArraySetAsSeries(m_src_high,  false);
      ArrayResize(m_src_low,   rates_total);
      ArraySetAsSeries(m_src_low,   false);
      ArrayResize(m_src_close, rates_total);
      ArraySetAsSeries(m_src_close, false);
      ArrayResize(m_raw_k,     rates_total);
      ArraySetAsSeries(m_raw_k,     false);
     }

// Safe allocation of output buffers
   if(ArraySize(k_buffer) != rates_total)
     {
      ArrayResize(k_buffer, rates_total);
      ArraySetAsSeries(k_buffer, false);
      ArrayInitialize(k_buffer, EMPTY_VALUE);
     }
   if(ArraySize(d_buffer) != rates_total)
     {
      ArrayResize(d_buffer, rates_total);
      ArraySetAsSeries(d_buffer, false);
      ArrayInitialize(d_buffer, EMPTY_VALUE);
     }

   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

// 1. Calculate Raw %K (Fast %K)
   int loop_start_k = MathMax(m_k_period - 1, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      double highest_h = Highest(m_k_period, i);
      double lowest_l  = Lowest(m_k_period, i);
      double range     = highest_h - lowest_l;

      if(range > 1.0e-9)
         m_raw_k[i] = ((m_src_close[i] - lowest_l) / range) * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i - 1] : 50.0;
     }

// 2. Calculate Slow %K (Main Line) using Slowing Engine
   int raw_k_offset = m_k_period - 1;
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, k_buffer, raw_k_offset);

// 3. Calculate %D (Signal Line) using Signal Engine
   int slow_k_offset = raw_k_offset + m_slowing_engine.GetPeriod() - 1;
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, slow_k_offset);
  }

//+------------------------------------------------------------------+
//| Prepare Source Data (Standard)                                   |
//+------------------------------------------------------------------+
bool CStochasticSlowCalculator::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i]  = high[i];
      m_src_low[i]   = low[i];
      m_src_close[i] = close[i];
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Helpers (Optimized Search Loops)                                 |
//+------------------------------------------------------------------+
double CStochasticSlowCalculator::Highest(int period, int current_pos)
  {
   double res = m_src_high[current_pos];
   for(int i = 1; i < period; i++)
     {
      double val = m_src_high[current_pos - i];
      if(val > res)
         res = val;
     }
   return res;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CStochasticSlowCalculator::Lowest(int period, int current_pos)
  {
   double res = m_src_low[current_pos];
   for(int i = 1; i < period; i++)
     {
      double val = m_src_low[current_pos - i];
      if(val < res)
         res = val;
     }
   return res;
  }

//+==================================================================+
//|         CLASS 2: CStochasticSlowCalculator_HA (Heikin Ashi)      |
//+==================================================================+
class CStochasticSlowCalculator_HA : public CStochasticSlowCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double                 m_ha_open[]; // Only HA open needs persistent state

protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Source Data (Direct In-Place Heikin Ashi Calculation)    |
//+------------------------------------------------------------------+
bool CStochasticSlowCalculator_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArraySetAsSeries(m_ha_open, false);
     }

// DIRECT IN-PLACE CALCULATION: Eliminates 3 temp arrays and 1 copy loop!
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_src_high, m_src_low, m_src_close);

   return true;
  }

#endif // STOCHASTIC_SLOW_CALCULATOR_MQH
//+------------------------------------------------------------------+
