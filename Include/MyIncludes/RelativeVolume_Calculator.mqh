//+------------------------------------------------------------------+
//|                                    RelativeVolume_Calculator.mqh |
//|      Engine for Relative Volume (RVOL) Calculation.              |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "1.20" // Enterprise Refactor: Pipelined Multipliers & Chronological Safety
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

   // Calculates RVOL for the series in O(1)
   void              Calculate(const int rates_total, const int prev_calculated, const long &volume[], double &rvol_buffer[]);

   // Calculates single value (Helper for Scripts)
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
//| Main Incremental Calculation (O(1) on live ticks)                |
//+------------------------------------------------------------------+
void CRelativeVolumeCalculator::Calculate(const int rates_total, const int prev_calculated, const long &volume[], double &rvol_buffer[])
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

   if(prev_calculated == 0)
     {
      for(int i = 0; i < m_period; i++)
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
//| Single Bar Calculator Helper                                     |
//+------------------------------------------------------------------+
double CRelativeVolumeCalculator::CalculateSingle(const int total, const long &volume[], const int index)
  {
   if(index < m_period || index >= total)
      return 0.0;

   double sum = 0.0;
   for(int k = 1; k <= m_period; k++)
      sum += (double)volume[index - k];

   double avg = sum * m_inv_period;
   return (avg > 1.0e-9) ? ((double)volume[index] / avg) : 0.0;
  }

#endif // RELATIVE_VOLUME_CALCULATOR_MQH
//+------------------------------------------------------------------+
