//+------------------------------------------------------------------+
//|                                               SMI_Calculator.mqh |
//|         Calculation engine for Standard and Heikin Ashi SMI.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CSMICalculator (Base Class)                 |
//|                                                                  |
//+==================================================================+
class CSMICalculator
  {
protected:
   int               m_len_k, m_len_d, m_len_ema;
   double            m_src_high[], m_src_low[], m_src_close[];

   double            Highest(int period, int current_pos);
   double            Lowest(int period, int current_pos);

   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CSMICalculator(void) {};
   virtual          ~CSMICalculator(void) {};

   bool              Init(int len_k, int len_d, int len_ema);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &smi_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//| CSMICalculator: Initialization                                   |
//+------------------------------------------------------------------+
bool CSMICalculator::Init(int len_k, int len_d, int len_ema)
  {
   m_len_k   = (len_k < 1) ? 1 : len_k;
   m_len_d   = (len_d < 1) ? 1 : len_d;
   m_len_ema = (len_ema < 1) ? 1 : len_ema;
   return true;
  }

//+------------------------------------------------------------------+
//| CSMICalculator: Main Calculation Method (Shared Logic)           |
//+------------------------------------------------------------------+
void CSMICalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &smi_buffer[], double &signal_buffer[])
  {
   int start_pos = m_len_k + m_len_d + m_len_d + m_len_ema - 4;
   if(rates_total <= start_pos)
      return;
   if(!PrepareSourceData(rates_total, open, high, low, close))
      return;

   double hl_range[], rel_range[], ema_rel[], ema_range[], ema_ema_rel[], ema_ema_range[];
   ArrayResize(hl_range, rates_total);
   ArrayResize(rel_range, rates_total);
   ArrayResize(ema_rel, rates_total);
   ArrayResize(ema_range, rates_total);
   ArrayResize(ema_ema_rel, rates_total);
   ArrayResize(ema_ema_range, rates_total);

   for(int i = m_len_k - 1; i < rates_total; i++)
     {
      double highest_h = Highest(m_len_k, i);
      double lowest_l  = Lowest(m_len_k, i);
      hl_range[i] = highest_h - lowest_l;
      rel_range[i] = m_src_close[i] - (highest_h + lowest_l) / 2.0;
     }

   double pr_d = 2.0 / (m_len_d + 1.0);
   double pr_ema = 2.0 / (m_len_ema + 1.0);
   int ema1_start = m_len_k + m_len_d - 2;
   int ema2_start = ema1_start + m_len_d - 1;
   int signal_start = ema2_start + m_len_ema - 1;

   for(int i = m_len_k - 1; i < rates_total; i++)
     {
      // --- 1st EMA Smoothing ---
      if(i == m_len_k - 1)
        {
         ema_rel[i] = rel_range[i];
         ema_range[i] = hl_range[i];
        }
      else
        {
         ema_rel[i] = rel_range[i] * pr_d + ema_rel[i-1] * (1.0 - pr_d);
         ema_range[i] = hl_range[i] * pr_d + ema_range[i-1] * (1.0 - pr_d);
        }

      // --- 2nd EMA Smoothing ---
      if(i >= ema1_start)
        {
         if(i == ema1_start)
           {
            double sum_rel=0, sum_ran=0;
            for(int j=0; j<m_len_d; j++)
              {
               sum_rel+=ema_rel[i-j];
               sum_ran+=ema_range[i-j];
              }
            ema_ema_rel[i] = sum_rel / m_len_d;
            ema_ema_range[i] = sum_ran / m_len_d;
           }
         else
           {
            ema_ema_rel[i] = ema_rel[i] * pr_d + ema_ema_rel[i-1] * (1.0 - pr_d);
            ema_ema_range[i] = ema_range[i] * pr_d + ema_ema_range[i-1] * (1.0 - pr_d);
           }
        }

      // --- Final SMI Value ---
      if(i >= ema2_start)
        {
         if(ema_ema_range[i] != 0)
            smi_buffer[i] = 100 * (ema_ema_rel[i] / (ema_ema_range[i] / 2.0));
         else
            smi_buffer[i] = 0;
        }

      // --- Signal Line ---
      if(i >= signal_start)
        {
         if(i == signal_start)
           {
            double sum_smi=0;
            for(int j=0; j<m_len_ema; j++)
               sum_smi += smi_buffer[i-j];
            signal_buffer[i] = sum_smi / m_len_ema;
           }
         else
           {
            signal_buffer[i] = smi_buffer[i] * pr_ema + signal_buffer[i-1] * (1.0 - pr_ema);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| CSMICalculator: Prepares the standard source data series.        |
//+------------------------------------------------------------------+
bool CSMICalculator::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_src_high, rates_total);
   ArrayCopy(m_src_high, high, 0, 0, rates_total);
   ArrayResize(m_src_low, rates_total);
   ArrayCopy(m_src_low, low, 0, 0, rates_total);
   ArrayResize(m_src_close, rates_total);
   ArrayCopy(m_src_close, close, 0, 0, rates_total);
   return true;
  }

//+------------------------------------------------------------------+
//| Finds the highest value in the internal price buffer.            |
//+------------------------------------------------------------------+
double CSMICalculator::Highest(int period, int current_pos)
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
//| Finds the lowest value in the internal price buffer.             |
//+------------------------------------------------------------------+
double CSMICalculator::Lowest(int period, int current_pos)
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
//|                                                                  |
//|           CLASS 2: CSMICalculator_HA (Heikin Ashi)               |
//|                                                                  |
//+==================================================================+
class CSMICalculator_HA : public CSMICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CSMICalculator_HA: Prepares the Heikin Ashi source data.         |
//+------------------------------------------------------------------+
bool CSMICalculator_HA::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(m_src_high, rates_total);
   ArrayResize(m_src_low, rates_total);
   ArrayResize(m_src_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, m_src_high, m_src_low, m_src_close);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
