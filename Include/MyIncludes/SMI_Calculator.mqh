//+------------------------------------------------------------------+
//|                                               SMI_Calculator.mqh |
//|         Calculation engine for Standard and Heikin Ashi SMI.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CSMICalculator (Base Class)                 |
//+==================================================================+
class CSMICalculator
  {
protected:
   int               m_len_k, m_len_d, m_len_ema;

   //--- Source Data Buffers (Persistent)
   double            m_src_high[], m_src_low[], m_src_close[];

   //--- Intermediate Calculation Buffers (Persistent state for incremental update)
   double            m_hl_range[], m_rel_range[];
   double            m_ema_rel[], m_ema_range[];
   double            m_ema_ema_rel[], m_ema_ema_range[];

   double            Highest(int period, int current_pos);
   double            Lowest(int period, int current_pos);

   //--- Updated: Accepts start_index
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CSMICalculator(void) {};
   virtual          ~CSMICalculator(void) {};

   bool              Init(int len_k, int len_d, int len_ema);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &smi_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CSMICalculator::Init(int len_k, int len_d, int len_ema)
  {
   m_len_k   = (len_k < 1) ? 1 : len_k;
   m_len_d   = (len_d < 1) ? 1 : len_d;
   m_len_ema = (len_ema < 1) ? 1 : len_ema;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation Method (Optimized Incremental)                  |
//+------------------------------------------------------------------+
void CSMICalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &smi_buffer[], double &signal_buffer[])
  {
   int start_pos = m_len_k + m_len_d + m_len_d + m_len_ema - 4;
   if(rates_total <= start_pos)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers if needed
   if(ArraySize(m_src_high) != rates_total)
     {
      ArrayResize(m_src_high, rates_total);
      ArrayResize(m_src_low, rates_total);
      ArrayResize(m_src_close, rates_total);

      ArrayResize(m_hl_range, rates_total);
      ArrayResize(m_rel_range, rates_total);
      ArrayResize(m_ema_rel, rates_total);
      ArrayResize(m_ema_range, rates_total);
      ArrayResize(m_ema_ema_rel, rates_total);
      ArrayResize(m_ema_ema_range, rates_total);
     }

//--- 3. Prepare Source Data (Optimized)
   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

//--- 4. Calculate Ranges
// Ensure we start at least from m_len_k-1 to have enough history for Highest/Lowest
   int loop_start = MathMax(m_len_k - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double highest_h = Highest(m_len_k, i);
      double lowest_l  = Lowest(m_len_k, i);
      m_hl_range[i] = highest_h - lowest_l;
      m_rel_range[i] = m_src_close[i] - (highest_h + lowest_l) / 2.0;
     }

//--- 5. Calculate EMAs and SMI
   double pr_d = 2.0 / (m_len_d + 1.0);
   double pr_ema = 2.0 / (m_len_ema + 1.0);
   int ema1_start = m_len_k + m_len_d - 2;
   int ema2_start = ema1_start + m_len_d - 1;
   int signal_start = ema2_start + m_len_ema - 1;

// We can reuse loop_start, but need to be careful about initialization logic
// If start_index is way past the initialization point, we just continue recursive calc.

   for(int i = loop_start; i < rates_total; i++)
     {
      // --- 1st EMA Smoothing ---
      if(i == m_len_k - 1)
        {
         m_ema_rel[i] = m_rel_range[i];
         m_ema_range[i] = m_hl_range[i];
        }
      else
        {
         // Recursive EMA relies on [i-1], which is safe due to persistent buffers
         m_ema_rel[i] = m_rel_range[i] * pr_d + m_ema_rel[i-1] * (1.0 - pr_d);
         m_ema_range[i] = m_hl_range[i] * pr_d + m_ema_range[i-1] * (1.0 - pr_d);
        }

      // --- 2nd EMA Smoothing ---
      if(i >= ema1_start)
        {
         if(i == ema1_start)
           {
            double sum_rel=0, sum_ran=0;
            for(int j=0; j<m_len_d; j++)
              {
               sum_rel+=m_ema_rel[i-j];
               sum_ran+=m_ema_range[i-j];
              }
            m_ema_ema_rel[i] = sum_rel / m_len_d;
            m_ema_ema_range[i] = sum_ran / m_len_d;
           }
         else
           {
            m_ema_ema_rel[i] = m_ema_rel[i] * pr_d + m_ema_ema_rel[i-1] * (1.0 - pr_d);
            m_ema_ema_range[i] = m_ema_range[i] * pr_d + m_ema_ema_range[i-1] * (1.0 - pr_d);
           }
        }

      // --- Final SMI Value ---
      if(i >= ema2_start)
        {
         if(m_ema_ema_range[i] != 0)
            smi_buffer[i] = 100 * (m_ema_ema_rel[i] / (m_ema_ema_range[i] / 2.0));
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
//| Prepare Source Data (Standard - Optimized)                       |
//+------------------------------------------------------------------+
bool CSMICalculator::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Optimized copy loop
   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i]  = high[i];
      m_src_low[i]   = low[i];
      m_src_close[i] = close[i];
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Highest                                                          |
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
//| Lowest                                                           |
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
//|             CLASS 2: CSMICalculator_HA (Heikin Ashi)             |
//+==================================================================+
class CSMICalculator_HA : public CSMICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers (Persistent)
   double            m_ha_open[], m_ha_high_temp[], m_ha_low_temp[], m_ha_close_temp[];

protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Source Data (Heikin Ashi - Optimized)                    |
//+------------------------------------------------------------------+
bool CSMICalculator_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high_temp, rates_total);
      ArrayResize(m_ha_low_temp, rates_total);
      ArrayResize(m_ha_close_temp, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
//--- Note: We calculate directly into the temporary buffers, then copy to m_src_...
//--- Actually, we can calculate directly into m_src_high/low/close if we want,
//--- but HA calc needs 4 buffers. m_src_... are 3 buffers.
//--- So we use temp buffers.

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high_temp, m_ha_low_temp, m_ha_close_temp);

//--- Copy to source buffers (Optimized loop)
   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i]  = m_ha_high_temp[i];
      m_src_low[i]   = m_ha_low_temp[i];
      m_src_close[i] = m_ha_close_temp[i];
     }
   return true;
  }
//+------------------------------------------------------------------+
