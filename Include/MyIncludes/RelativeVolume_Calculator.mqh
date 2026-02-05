//+------------------------------------------------------------------+
//|                                    RelativeVolume_Calculator.mqh |
//|      Engine for Relative Volume (RVOL) Calculation.              |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CRelativeVolumeCalculator
  {
protected:
   int               m_period;
   long              m_vol_buffer[]; // Stores volume series

public:
                     CRelativeVolumeCalculator() : m_period(20) {};
                    ~CRelativeVolumeCalculator() {};

   bool              Init(int period);

   // Calculates RVOL for the entire series
   void              Calculate(int rates_total, int prev_calculated, const long &volume[], double &rvol_buffer[]);

   // Calculates single value (Helper for Scripts)
   double            CalculateSingle(int total, const long &volume[], int index);
  };

//+------------------------------------------------------------------+
bool CRelativeVolumeCalculator::Init(int period)
  {
   m_period = (period < 1) ? 1 : period;
   return true;
  }

//+------------------------------------------------------------------+
void CRelativeVolumeCalculator::Calculate(int rates_total, int prev_calculated, const long &volume[], double &rvol_buffer[])
  {
   if(rates_total <= m_period)
      return;

   int start_index = (prev_calculated > m_period) ? prev_calculated - 1 : m_period;

   for(int i = start_index; i < rates_total; i++)
     {
      double sum = 0;
      // Sum previous N bars (excluding current i)
      for(int k = 1; k <= m_period; k++)
         sum += (double)volume[i-k];

      double avg = sum / m_period;

      if(avg > 0)
         rvol_buffer[i] = (double)volume[i] / avg;
      else
         rvol_buffer[i] = 0.0;
     }
  }

//+------------------------------------------------------------------+
double CRelativeVolumeCalculator::CalculateSingle(int total, const long &volume[], int index)
  {
   if(index < m_period || index >= total)
      return 0.0;

   double sum = 0;
   for(int k = 1; k <= m_period; k++)
      sum += (double)volume[index-k];

   double avg = sum / m_period;

   return (avg > 0) ? (double)volume[index] / avg : 0.0;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
