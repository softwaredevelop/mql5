//+------------------------------------------------------------------+
//|                                             Aroon_Calculator.mqh |
//|        Calculation engine for Standard and Heikin Ashi Aroon.    |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CAroonCalculator (Base Class)               |
//+==================================================================+
class CAroonCalculator
  {
protected:
   int               m_aroon_period;

   //--- Persistent Buffers for Incremental Calculation
   double            m_high_buffer[];
   double            m_low_buffer[];

   //--- Updated: Accepts start_index and all price arrays
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CAroonCalculator(void) {};
   virtual          ~CAroonCalculator(void) {};

   bool              Init(int period);
   int               GetPeriod(void) const { return m_aroon_period; }

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &aroon_up_buffer[], double &aroon_down_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CAroonCalculator::Init(int period)
  {
   m_aroon_period = (period < 1) ? 1 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CAroonCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                                 double &aroon_up_buffer[], double &aroon_down_buffer[])
  {
   if(rates_total < m_aroon_period)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Internal Buffers
   if(ArraySize(m_high_buffer) != rates_total)
     {
      ArrayResize(m_high_buffer, rates_total);
      ArrayResize(m_low_buffer, rates_total);
     }

//--- 3. Prepare Source Data (Optimized)
   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

//--- 4. Calculate Aroon (Incremental Loop)
   int loop_start = MathMax(m_aroon_period - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double highest_val = -DBL_MAX;
      int    highest_idx = -1;
      double lowest_val  = DBL_MAX;
      int    lowest_idx  = -1;

      // Inner loop: Look back over the defined period
      // Optimization: For very large periods, this inner loop is O(N*M).
      // For standard periods (14-25), it's fast enough.
      for(int j = i - m_aroon_period + 1; j <= i; j++)
        {
         if(m_high_buffer[j] >= highest_val)
           {
            highest_val = m_high_buffer[j];
            highest_idx = j;
           }
         if(m_low_buffer[j] <= lowest_val)
           {
            lowest_val = m_low_buffer[j];
            lowest_idx = j;
           }
        }

      int bars_since_high = i - highest_idx;
      int bars_since_low  = i - lowest_idx;

      aroon_up_buffer[i]   = (double)(m_aroon_period - bars_since_high) / m_aroon_period * 100.0;
      aroon_down_buffer[i] = (double)(m_aroon_period - bars_since_low) / m_aroon_period * 100.0;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Source Data (Standard - Optimized)                       |
//+------------------------------------------------------------------+
bool CAroonCalculator::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      m_high_buffer[i] = high[i];
      m_low_buffer[i]  = low[i];
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CAroonCalculator_HA (Heikin Ashi)           |
//+==================================================================+
class CAroonCalculator_HA : public CAroonCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Source Data (Heikin Ashi - Optimized)                    |
//+------------------------------------------------------------------+
bool CAroonCalculator_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

//--- Copy to source buffers (Optimized loop)
   for(int i = start_index; i < rates_total; i++)
     {
      m_high_buffer[i] = m_ha_high[i];
      m_low_buffer[i]  = m_ha_low[i];
     }
   return true;
  }
//+------------------------------------------------------------------+
