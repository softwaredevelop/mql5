//+------------------------------------------------------------------+
//|                                             Vortex_Calculator.mqh|
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CVortexCalculator (Base Class)              |
//+==================================================================+
class CVortexCalculator
  {
protected:
   int               m_period;

   //--- Persistent Buffers for Incremental Calculation
   double            m_src_high[], m_src_low[], m_src_close[];
   double            m_tr[], m_vm_plus[], m_vm_minus[];

   //--- Updated: Accepts start_index
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CVortexCalculator(void) {};
   virtual          ~CVortexCalculator(void) {};

   bool              Init(int period);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &vi_plus_buffer[], double &vi_minus_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CVortexCalculator::Init(int period)
  {
   m_period = (period < 1) ? 1 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CVortexCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                                  double &vi_plus_buffer[], double &vi_minus_buffer[])
  {
   if(rates_total <= m_period)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_src_high) != rates_total)
     {
      ArrayResize(m_src_high, rates_total);
      ArrayResize(m_src_low, rates_total);
      ArrayResize(m_src_close, rates_total);
      ArrayResize(m_tr, rates_total);
      ArrayResize(m_vm_plus, rates_total);
      ArrayResize(m_vm_minus, rates_total);
     }

//--- 3. Prepare Source Data (Optimized)
   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

//--- 4. Calculate TR and VM (Incremental)
   int loop_start_tr = MathMax(1, start_index);

   for(int i = loop_start_tr; i < rates_total; i++)
     {
      m_tr[i]       = MathMax(m_src_high[i], m_src_close[i-1]) - MathMin(m_src_low[i], m_src_close[i-1]);
      m_vm_plus[i]  = MathAbs(m_src_high[i] - m_src_low[i-1]);
      m_vm_minus[i] = MathAbs(m_src_low[i] - m_src_high[i-1]);
     }

//--- 5. Calculate Vortex (Incremental Sliding Window)
   int loop_start_vi = MathMax(m_period, start_index);

   for(int i = loop_start_vi; i < rates_total; i++)
     {
      double sum_tr = 0, sum_vplus = 0, sum_vminus = 0;

      // Sum over the lookback period
      // Optimization: For standard periods (14-21), a loop is fast enough.
      for(int j = 0; j < m_period; j++)
        {
         sum_tr     += m_tr[i-j];
         sum_vplus  += m_vm_plus[i-j];
         sum_vminus += m_vm_minus[i-j];
        }

      if(sum_tr > 0)
        {
         vi_plus_buffer[i]  = sum_vplus / sum_tr;
         vi_minus_buffer[i] = sum_vminus / sum_tr;
        }
      else
        {
         vi_plus_buffer[i]  = 0;
         vi_minus_buffer[i] = 0;
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Source Data (Standard - Optimized)                       |
//+------------------------------------------------------------------+
bool CVortexCalculator::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i] = high[i];
      m_src_low[i]  = low[i];
      m_src_close[i] = close[i];
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CVortexCalculator_HA (Heikin Ashi)          |
//+==================================================================+
class CVortexCalculator_HA : public CVortexCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[];

protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Source Data (Heikin Ashi - Optimized)                    |
//+------------------------------------------------------------------+
bool CVortexCalculator_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
      ArrayResize(m_ha_open, rates_total);

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_src_high, m_src_low, m_src_close);

   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
