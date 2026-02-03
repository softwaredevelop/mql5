//+------------------------------------------------------------------+
//|                                            RVOL_Calculator.mqh   |
//|               Engine for Relative Volume calculation.            |
//|                                       Copyright 2026, xxxxxxxx   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // No changes needed

//+==================================================================+
//| CLASS: CRVOLCalculator                                           |
//+==================================================================+
class CRVOLCalculator
  {
protected:
   int               m_period;

public:
                     CRVOLCalculator(void) {}
                    ~CRVOLCalculator(void) {}

   bool              Init(int period);

   void              Calculate(int rates_total,
                               int prev_calculated,
                               const long &volume[],
                               double &out_buffer[]);
  };

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CRVOLCalculator::Init(int period)
  {
   m_period = (period < 1) ? 1 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation Logic                                           |
//+------------------------------------------------------------------+
void CRVOLCalculator::Calculate(int rates_total,
                                int prev_calculated,
                                const long &volume[],
                                double &out_buffer[])
  {
   if(rates_total <= m_period)
      return;

   int limit;
   if(prev_calculated == 0)
     {
      limit = m_period;
     }
   else
     {
      limit = prev_calculated - 1;
     }

   for(int i = limit; i < rates_total; i++)
     {
      double sum = 0;
      for(int j = 1; j <= m_period; j++)
        {
         sum += (double)volume[i - j];
        }

      double average_volume = sum / m_period;

      if(average_volume > 0)
        {
         out_buffer[i] = (double)volume[i] / average_volume;
        }
      else
        {
         out_buffer[i] = 1.0;
        }
     }
  }
//+------------------------------------------------------------------+
