//+------------------------------------------------------------------+
//|                                     StochasticSlow_Calculator.mqh|
//|      VERSION 2.00: Uses MovingAverage_Engine for smoothing.      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|           CLASS: CStochasticSlowCalculator                       |
//+==================================================================+
class CStochasticSlowCalculator
  {
protected:
   int               m_k_period;

   //--- Composition: Two MA Engines
   CMovingAverageCalculator m_slowing_engine; // For Slow %K
   CMovingAverageCalculator m_signal_engine;  // For %D

   //--- Persistent Buffers
   double            m_src_high[], m_src_low[], m_src_close[];
   double            m_raw_k[]; // Stores Fast %K (intermediate)

   double            Highest(int period, int current_pos);
   double            Lowest(int period, int current_pos);

   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CStochasticSlowCalculator(void) {};
   virtual          ~CStochasticSlowCalculator(void) {};

   //--- Init now takes ENUM_MA_TYPE for both smoothings
   bool              Init(int k_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochasticSlowCalculator::Init(int k_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma)
  {
   m_k_period = (k_p < 1) ? 1 : k_p;

// Initialize both engines
   if(!m_slowing_engine.Init(slow_p, slow_ma))
      return false;
   if(!m_signal_engine.Init(d_p, d_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CStochasticSlowCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
// Check minimum bars required
   int min_bars = m_k_period + m_slowing_engine.GetPeriod() + m_signal_engine.GetPeriod();
   if(rates_total <= min_bars)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_src_high) != rates_total)
     {
      ArrayResize(m_src_high, rates_total);
      ArrayResize(m_src_low, rates_total);
      ArrayResize(m_src_close, rates_total);
      ArrayResize(m_raw_k, rates_total);
     }

   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

//--- 1. Calculate Raw %K (Fast %K)
   int loop_start_k = MathMax(m_k_period - 1, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      double highest_h = Highest(m_k_period, i);
      double lowest_l  = Lowest(m_k_period, i);
      double range = highest_h - lowest_l;

      if(range > 0)
         m_raw_k[i] = (m_src_close[i] - lowest_l) / range * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i-1] : 50.0;
     }

//--- 2. Calculate Slow %K (Main Line) using Slowing Engine
// Offset for Raw %K is (K - 1)
   int raw_k_offset = m_k_period - 1;

// Output goes to k_buffer (this is the main Slow Stochastic line)
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, k_buffer, raw_k_offset);

//--- 3. Calculate %D (Signal Line) using Signal Engine
// Offset for Slow %K is (Raw_Offset + Slowing_Period - 1)
   int slow_k_offset = raw_k_offset + m_slowing_engine.GetPeriod() - 1;

// Input is k_buffer (Slow %K), Output is d_buffer
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
//| Helpers                                                          |
//+------------------------------------------------------------------+
double CStochasticSlowCalculator::Highest(int period, int current_pos)
  {
   double res = m_src_high[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res < m_src_high[index])
         res = m_src_high[index];
     }
   return(res);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CStochasticSlowCalculator::Lowest(int period, int current_pos)
  {
   double res = m_src_low[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res > m_src_low[index])
         res = m_src_low[index];
     }
   return(res);
  }

//+==================================================================+
//|         CLASS 2: CStochasticSlowCalculator_HA (Heikin Ashi)      |
//+==================================================================+
class CStochasticSlowCalculator_HA : public CStochasticSlowCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high_temp[], m_ha_low_temp[], m_ha_close_temp[];
protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CStochasticSlowCalculator_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high_temp, rates_total);
      ArrayResize(m_ha_low_temp, rates_total);
      ArrayResize(m_ha_close_temp, rates_total);
     }
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_ha_high_temp, m_ha_low_temp, m_ha_close_temp);
   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i]  = m_ha_high_temp[i];
      m_src_low[i]   = m_ha_low_temp[i];
      m_src_close[i] = m_ha_close_temp[i];
     }
   return true;
  }
//+------------------------------------------------------------------+
