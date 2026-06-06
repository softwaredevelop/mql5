//+------------------------------------------------------------------+
//|                                                   LLD_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.21" // Optimized, prefix-free calculator
#property description "High-Performance Lead-Lag Cross-Correlation Calculator"

#ifndef LLD_CALCULATOR_MQH
#define LLD_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//| CLASS: CLeadLagDominanceCalculator                               |
//+==================================================================+
class CLeadLagDominanceCalculator
  {
private:
   int               m_window;
   int               m_max_lag;

   double            m_price_A[];
   double            m_price_B[];
   double            m_returns_A[];
   double            m_returns_B[];

   //--- Pearson Correlation for shifted arrays
   double            ComputePearson(const double &x[], const double &y[], int start_x, int start_y, int length);

public:
                     CLeadLagDominanceCalculator(void) : m_window(50), m_max_lag(10) {};
                    ~CLeadLagDominanceCalculator(void) {};

   bool              Init(int window, int max_lag);

   //--- Dynamic calculation of dominance index and optimal lag
   bool              CalculateDominance(const int rates_total,
                                        const int start_index,
                                        const double &close_A[],
                                        const double &close_B[],
                                        double &lldi_buffer[],
                                        double &lag_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLeadLagDominanceCalculator::Init(int window, int max_lag)
  {
   m_window = (window < 5) ? 5 : window;
   m_max_lag = (max_lag < 1) ? 1 : max_lag;
   return true;
  }

//+------------------------------------------------------------------+
//| CalculateDominance                                               |
//+------------------------------------------------------------------+
bool CLeadLagDominanceCalculator::CalculateDominance(const int rates_total,
      const int start_index,
      const double &close_A[],
      const double &close_B[],
      double &lldi_buffer[],
      double &lag_buffer[])
  {
   int required_bars = m_window + m_max_lag + 2;
   if(rates_total < required_bars)
      return false;

//--- Handle dynamic arrays for returns
   if(ArraySize(m_returns_A) != rates_total)
     {
      ArrayResize(m_returns_A, rates_total);
      ArrayResize(m_returns_B, rates_total);
     }

   int calc_start = (start_index == 0) ? 1 : start_index;

//--- 1. Calculate Log-Returns to ensure stationarity
   for(int i = calc_start; i < rates_total; i++)
     {
      m_returns_A[i] = (close_A[i-1] > 0) ? MathLog(close_A[i] / close_A[i-1]) : 0.0;
      m_returns_B[i] = (close_B[i-1] > 0) ? MathLog(close_B[i] / close_B[i-1]) : 0.0;
     }

//--- Define safe processing loop boundaries
   int start_pos = m_window + m_max_lag + 1;
   int loop_start = MathMax(start_pos, start_index);

//--- 2. Rolling Cross-Correlation Sweep
   for(int i = loop_start; i < rates_total; i++)
     {
      double peak_B_leads_A = 0.0;
      int    opt_lag_B_leads = 0;

      double peak_A_leads_B = 0.0;
      int    opt_lag_A_leads = 0;

      //--- Test all lags up to m_max_lag
      for(int k = 1; k <= m_max_lag; k++)
        {
         // Direction 1: B leads A (B's past predicts A's present)
         double r_B_leads = ComputePearson(m_returns_B, m_returns_A, i - m_window + 1 - k, i - m_window + 1, m_window);
         if(MathAbs(r_B_leads) > MathAbs(peak_B_leads_A))
           {
            peak_B_leads_A = r_B_leads;
            opt_lag_B_leads = k;
           }

         // Direction 2: A leads B (A's past predicts B's present)
         double r_A_leads = ComputePearson(m_returns_A, m_returns_B, i - m_window + 1 - k, i - m_window + 1, m_window);
         if(MathAbs(r_A_leads) > MathAbs(peak_A_leads_B))
           {
            peak_A_leads_B = r_A_leads;
            opt_lag_A_leads = k;
           }
        }

      //--- 3. Compute Dominance Metrics
      double abs_B_leads = MathAbs(peak_B_leads_A);
      double abs_A_leads = MathAbs(peak_A_leads_B);

      lldi_buffer[i] = abs_B_leads - abs_A_leads;

      //--- Sign the optimal lag: Positive if B leads, Negative if A leads
      if(abs_B_leads > abs_A_leads)
        {
         lag_buffer[i] = (double)opt_lag_B_leads;
        }
      else
         if(abs_A_leads > abs_B_leads)
           {
            lag_buffer[i] = -(double)opt_lag_A_leads;
           }
         else
           {
            lag_buffer[i] = 0.0;
           }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| ComputePearson                                                   |
//+------------------------------------------------------------------+
double CLeadLagDominanceCalculator::ComputePearson(const double &x[], const double &y[], int start_x, int start_y, int length)
  {
   if(length <= 1)
      return 0.0;

   double sum_x = 0.0, sum_y = 0.0;
   for(int i = 0; i < length; i++)
     {
      sum_x += x[start_x + i];
      sum_y += y[start_y + i];
     }
   double mean_x = sum_x / length;
   double mean_y = sum_y / length;

   double cov = 0.0;
   double var_x = 0.0;
   double var_y = 0.0;

   for(int i = 0; i < length; i++)
     {
      double dx = x[start_x + i] - mean_x;
      double dy = y[start_y + i] - mean_y;
      cov += dx * dy;
      var_x += dx * dx;
      var_y += dy * dy;
     }

   if(var_x <= 0.0 || var_y <= 0.0)
      return 0.0;

   double r = cov / MathSqrt(var_x * var_y);

//--- Boundary clamp
   if(r > 1.0)
      r = 1.0;
   if(r < -1.0)
      r = -1.0;

   return r;
  }

#endif // LLD_CALCULATOR_MQH
//+------------------------------------------------------------------+
