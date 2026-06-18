//+------------------------------------------------------------------+
//|                                     LLD_Calculator.mqh           |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.31" // Fixed dynamic index-based computation to eliminate CPU deadlock

#ifndef LLD_CALCULATOR_MQH
#define LLD_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS: CLeadLagDominanceCalculator                   |
//+==================================================================+
class CLeadLagDominanceCalculator
  {
private:
   int               m_max_window;
   int               m_max_lag;

   double            m_returns_A[];
   double            m_returns_B[];

   //--- Pearson Correlation for shifted arrays
   double            ComputePearson(const double &x[], const double &y[], int start_x, int start_y, int length);

public:
                     CLeadLagDominanceCalculator(void) : m_max_window(120), m_max_lag(10) {};
                    ~CLeadLagDominanceCalculator(void) {};

   bool              Init(int max_window, int max_lag);

   //--- FIXED: Single index computation in O(1) to prevent double-nested loop frosen state
   bool              CalculateDominance(const int rates_total,
                                        const int current_index, // Single target index!
                                        const int window_size,
                                        const double &close_A[],
                                        const double &close_B[],
                                        double &out_lldi,        // Out variables passed as reference
                                        double &out_lag);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLeadLagDominanceCalculator::Init(int max_window, int max_lag)
  {
   m_max_window = (max_window < 10) ? 10 : max_window;
   m_max_lag = (max_lag < 1) ? 1 : max_lag;
   return true;
  }

//+------------------------------------------------------------------+
//| CalculateDominance (Dynamic Window Cross-Correlation)            |
//+------------------------------------------------------------------+
bool CLeadLagDominanceCalculator::CalculateDominance(const int rates_total,
      const int current_index,
      const int window_size,
      const double &close_A[],
      const double &close_B[],
      double &out_lldi,
      double &out_lag)
  {
// Safety 1: Enforce minimum bars to allow full lag-interval shift on anchored starts
   int required_bars = window_size + m_max_lag + 2;
   if(rates_total < required_bars || window_size < m_max_lag + 15 || current_index < required_bars - 1)
     {
      out_lldi = 0.0;
      out_lag = 0.0;
      return false; // Not enough data points accumulated in the current anchor period yet
     }

//--- Handle dynamic arrays for returns
   if(ArraySize(m_returns_A) != rates_total)
     {
      ArrayResize(m_returns_A, rates_total);
      ArrayResize(m_returns_B, rates_total);
     }

//--- 1. Calculate Log-Returns incrementally for the current index (O(1))
   m_returns_A[current_index] = (close_A[current_index-1] > 0) ? MathLog(close_A[current_index] / close_A[current_index-1]) : 0.0;
   m_returns_B[current_index] = (close_B[current_index-1] > 0) ? MathLog(close_B[current_index] / close_B[current_index-1]) : 0.0;

//--- 2. Single-bar Cross-Correlation Sweep (FIXED: removed nested loops!)
   int i = current_index;
   double peak_B_leads_A = 0.0;
   int    opt_lag_B_leads = 0;

   double peak_A_leads_B = 0.0;
   int    opt_lag_A_leads = 0;

//--- Test all lags up to m_max_lag
   for(int k = 1; k <= m_max_lag; k++)
     {
      // Direction 1: B leads A (B's past predicts A's present)
      double r_B_leads = ComputePearson(m_returns_B, m_returns_A, i - window_size + 1 - k, i - window_size + 1, window_size);
      if(MathAbs(r_B_leads) > MathAbs(peak_B_leads_A))
        {
         peak_B_leads_A = r_B_leads;
         opt_lag_B_leads = k;
        }

      // Direction 2: A leads B (A's past predicts B's present)
      double r_A_leads = ComputePearson(m_returns_A, m_returns_B, i - window_size + 1 - k, i - window_size + 1, window_size);
      if(MathAbs(r_A_leads) > MathAbs(peak_A_leads_B))
        {
         peak_A_leads_B = r_A_leads;
         opt_lag_A_leads = k;
        }
     }

//--- 3. Compute Dominance Metrics
   double abs_B_leads = MathAbs(peak_B_leads_A);
   double abs_A_leads = MathAbs(peak_A_leads_B);

   out_lldi = abs_B_leads - abs_A_leads;

//--- Sign the optimal lag: Positive if B leads, Negative if A leads
   if(abs_B_leads > abs_A_leads)
     {
      out_lag = (double)opt_lag_B_leads;
     }
   else
      if(abs_A_leads > abs_B_leads)
        {
         out_lag = -(double)opt_lag_A_leads;
        }
      else
        {
         out_lag = 0.0;
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
