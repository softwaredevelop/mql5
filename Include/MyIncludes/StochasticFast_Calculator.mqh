//+------------------------------------------------------------------+
//|                                     StochasticFast_Calculator.mqh|
//|      VERSION 2.10: Fixed %D smoothing offset.                    |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|           CLASS: CStochasticFastCalculator                       |
//+==================================================================+
class CStochasticFastCalculator
  {
protected:
   int               m_k_period;

   //--- Composition: Use MA Engine for %D smoothing
   CMovingAverageCalculator m_ma_engine;

   //--- Persistent Buffers
   double            m_src_high[], m_src_low[], m_src_close[];

   double            Highest(int period, int current_pos);
   double            Lowest(int period, int current_pos);

   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CStochasticFastCalculator(void) {};
   virtual          ~CStochasticFastCalculator(void) {};

   //--- Init now takes ENUM_MA_TYPE (extended types)
   bool              Init(int k_p, int d_p, ENUM_MA_TYPE d_ma);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochasticFastCalculator::Init(int k_p, int d_p, ENUM_MA_TYPE d_ma)
  {
   m_k_period  = (k_p < 1) ? 1 : k_p;

// Initialize the MA Engine for %D
   return m_ma_engine.Init(d_p, d_ma);
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CStochasticFastCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
// Ensure we have enough bars for K + D calculation
   if(rates_total <= m_k_period + m_ma_engine.GetPeriod())
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_src_high) != rates_total)
     {
      ArrayResize(m_src_high, rates_total);
      ArrayResize(m_src_low, rates_total);
      ArrayResize(m_src_close, rates_total);
     }

   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

//--- 1. Calculate %K (Fast %K)
   int loop_start_k = MathMax(m_k_period - 1, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      double highest_h = Highest(m_k_period, i);
      double lowest_l  = Lowest(m_k_period, i);
      double range = highest_h - lowest_l;

      if(range > 0)
         k_buffer[i] = (m_src_close[i] - lowest_l) / range * 100.0;
      else
         k_buffer[i] = (i > 0) ? k_buffer[i-1] : 50.0;
     }

//--- 2. Calculate %D using the MA Engine (CalculateOnArray)
// CRITICAL: Pass 'm_k_period - 1' as the offset.
// This tells the MA Engine that valid data in k_buffer starts at index (K-1).
   m_ma_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, m_k_period - 1);
  }

//+------------------------------------------------------------------+
//| Prepare Source Data (Standard)                                   |
//+------------------------------------------------------------------+
bool CStochasticFastCalculator::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
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
//| Helpers (Highest/Lowest)                                         |
//+------------------------------------------------------------------+
double CStochasticFastCalculator::Highest(int period, int current_pos)
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
double CStochasticFastCalculator::Lowest(int period, int current_pos)
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
//|         CLASS 2: CStochasticFastCalculator_HA (Heikin Ashi)      |
//+==================================================================+
class CStochasticFastCalculator_HA : public CStochasticFastCalculator
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
bool CStochasticFastCalculator_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
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
