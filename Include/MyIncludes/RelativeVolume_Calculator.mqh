//+------------------------------------------------------------------+
//|                                    RelativeVolume_Calculator.mqh |
//|      Engine for Relative Volume (RVOL) Calculation.              |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "1.30" // Enterprise Refactor: Pipelined Multipliers & 100% Backward Compatibility
#property description "High-performance calculation engine for Relative Volume (RVOL)."

#ifndef RELATIVE_VOLUME_CALCULATOR_MQH
#define RELATIVE_VOLUME_CALCULATOR_MQH

//+==================================================================+
//|             CLASS: CRelativeVolumeCalculator                     |
//+==================================================================+
class CRelativeVolumeCalculator
  {
protected:
   int               m_period;
   double            m_inv_period; // Precalculated 1.0 / period

public:
                     CRelativeVolumeCalculator(void) : m_period(20), m_inv_period(0.05) {};
   virtual          ~CRelativeVolumeCalculator(void) {};

   bool              Init(const int period);
   int               GetPeriod(void) const { return m_period; }

   //--- STRICT INTERFACE 1: Original 4-param signature (100% backward compatible)
   void              Calculate(const int rates_total, const int prev_calculated, const long &volume[], double &rvol_buffer[]);

   //--- EXTENDED INTERFACE 2: With history limit support for massive workspaces
   void              Calculate(const int rates_total, const int prev_calculated, const long &volume[], double &rvol_buffer[], const int history_limit);

   //--- Calculates single value (Helper for Scripts and Real-time MTF Candle Mocking)
   double            CalculateSingle(const int total, const long &volume[], const int index);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CRelativeVolumeCalculator::Init(const int period)
  {
   m_period     = (period < 1) ? 1 : period;
   m_inv_period = 1.0 / (double)m_period;
   return true;
  }

//+------------------------------------------------------------------+
//| Legacy Signature: 4-Parameters (100% Backward Compatible)        |
//+------------------------------------------------------------------+
void CRelativeVolumeCalculator::Calculate(const int rates_total, const int prev_calculated, const long &volume[], double &rvol_buffer[])
  {
   Calculate(rates_total, prev_calculated, volume, rvol_buffer, 0);
  }

//+------------------------------------------------------------------+
//| Extended Signature: With History Limit & Pipelined Execution     |
//+------------------------------------------------------------------+
void CRelativeVolumeCalculator::Calculate(const int rates_total, const int prev_calculated, const long &volume[], double &rvol_buffer[], const int history_limit)
  {
   if(rates_total <= m_period)
      return;

// Safe allocation of output buffer
   if(ArraySize(rvol_buffer) != rates_total)
     {
      ArrayResize(rvol_buffer, rates_total);
      ArraySetAsSeries(rvol_buffer, false);
     }

   int start_index = (prev_calculated > m_period) ? (prev_calculated - 1) : m_period;
   if(history_limit > 0 && prev_calculated == 0)
     {
      int limit_start = rates_total - history_limit;
      if(limit_start > start_index)
         start_index = limit_start;
     }

   if(prev_calculated == 0)
     {
      for(int i = 0; i < start_index; i++)
         rvol_buffer[i] = 0.0;
     }

   for(int i = start_index; i < rates_total; i++)
     {
      double sum = 0.0;
      for(int k = 1; k <= m_period; k++)
         sum += (double)volume[i - k];

      double avg = sum * m_inv_period;

      if(avg > 1.0e-9)
         rvol_buffer[i] = (double)volume[i] / avg;
      else
         rvol_buffer[i] = 0.0;
     }
  }

//+------------------------------------------------------------------+
//| Single Bar Calculator Helper (Protected Memory Bounds)           |
//+------------------------------------------------------------------+
double CRelativeVolumeCalculator::CalculateSingle(const int total, const long &volume[], const int index)
  {
   if(index < m_period || index >= total || ArraySize(volume) < total)
      return 0.0;

   double sum = 0.0;
   for(int k = 1; k <= m_period; k++)
      sum += (double)volume[index - k];

   double avg = sum * m_inv_period;
   return (avg > 1.0e-9) ? ((double)volume[index] / avg) : 0.0;
  }

#endif // RELATIVE_VOLUME_CALCULATOR_MQH
//+------------------------------------------------------------------+