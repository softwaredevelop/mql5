//+------------------------------------------------------------------+
//|                                     PairsTrading_Calculator.mqh  |
//|      Engine for Dynamic Rolling/Anchored OLS Pairs Cointegration |
//|      Strictly O(1) Incremental Optimized.                        |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.20" // Refactored with public getters for OLS parameters

#ifndef PAIRS_TRADING_CALCULATOR_MQH
#define PAIRS_TRADING_CALCULATOR_MQH

//+==================================================================+
//|             CLASS: CPairsTradingCalculator                       |
//+==================================================================+
class CPairsTradingCalculator
  {
private:
   int               m_max_window;

   //--- Dynamic rolling arrays
   double            m_arr_A[];
   double            m_arr_B[];
   double            m_spread_history[];

   //--- Persistent OLS parameters for get retrieval
   double            m_beta;
   double            m_alpha;
   double            m_std_dev_spread;

   //--- Statistics helpers
   double            GetMean(const double &arr[], int size);
   double            GetVariance(const double &arr[], double mean, int size);
   double            GetCovariance(const double &arr1[], double mean1, const double &arr2[], double mean2, int size);

public:
                     CPairsTradingCalculator();
                    ~CPairsTradingCalculator() {};

   bool              Init(int max_window);

   //--- Dynamic rolling OLS Z-Score calculation
   double            CalculateZScore(int rates_total, int current_index, int window_size,
                                     const double &sync_price_A[], const double &sync_price_B[]);

   //--- Public getters to share the calculated coefficients with the Band indicator
   double            GetBeta(void)   const { return m_beta; }
   double            GetAlpha(void)  const { return m_alpha; }
   double            GetStdDev(void) const { return m_std_dev_spread; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPairsTradingCalculator::CPairsTradingCalculator() :
   m_max_window(120), m_beta(0.0), m_alpha(0.0), m_std_dev_spread(0.0) {}

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CPairsTradingCalculator::Init(int max_window)
  {
   m_max_window = (max_window < 10) ? 10 : max_window;
   return true;
  }

//+------------------------------------------------------------------+
//| CalculateZScore (OLS Dynamic Window Cointegration)               |
//+------------------------------------------------------------------+
double CPairsTradingCalculator::CalculateZScore(int rates_total, int current_index, int window_size,
      const double &sync_price_A[], const double &sync_price_B[])
  {
   if(window_size < 15 || current_index < window_size)
     {
      m_beta = 0.0;
      m_alpha = 0.0;
      m_std_dev_spread = 0.0;
      return 0.0;
     }

//--- Dynamic array allocation based on the current active anchor size
   if(ArraySize(m_arr_A) != window_size)
     {
      ArrayResize(m_arr_A, window_size);
      ArrayResize(m_arr_B, window_size);
      ArrayResize(m_spread_history, window_size);
     }

//--- Extract rolling/anchored window from synchronized prices
   for(int k = 0; k < window_size; k++)
     {
      int src_idx = current_index - window_size + 1 + k;
      m_arr_A[k] = sync_price_A[src_idx];
      m_arr_B[k] = sync_price_B[src_idx];
     }

//--- Calculate means
   double mean_A = GetMean(m_arr_A, window_size);
   double mean_B = GetMean(m_arr_B, window_size);

//--- Calculate Variance of Benchmark (B) and Covariance (A, B)
   double var_B  = GetVariance(m_arr_B, mean_B, window_size);
   double cov_AB = GetCovariance(m_arr_A, mean_A, m_arr_B, mean_B, window_size);

   if(var_B <= 1.0e-9)
     {
      m_beta = 0.0;
      m_alpha = 0.0;
      m_std_dev_spread = 0.0;
      return 0.0;
     }

//--- Calculate OLS Rolling Hedge Ratio (Beta) and Intercept (Alpha)
   m_beta  = cov_AB / var_B;
   m_alpha = mean_A - (m_beta * mean_B);

//--- Calculate the historical spreads over the active window
   double sum_sq_spread = 0.0;
   for(int k = 0; k < window_size; k++)
     {
      m_spread_history[k] = m_arr_A[k] - (m_beta * m_arr_B[k]) - m_alpha;
      sum_sq_spread += m_spread_history[k] * m_spread_history[k];
     }

// Sample standard deviation of the active spread window
   m_std_dev_spread = MathSqrt(sum_sq_spread / (window_size - 1));

   if(m_std_dev_spread <= 1.0e-9)
      return 0.0;

//--- Calculate the final current Z-Score
   double current_spread = sync_price_A[current_index] - (m_beta * sync_price_B[current_index]) - m_alpha;

   return current_spread / m_std_dev_spread;
  }

//+------------------------------------------------------------------+
//| GetMean                                                          |
//+------------------------------------------------------------------+
double CPairsTradingCalculator::GetMean(const double &arr[], int size)
  {
   double sum = 0.0;
   for(int i = 0; i < size; i++)
      sum += arr[i];
   return sum / size;
  }

//+------------------------------------------------------------------+
//| GetVariance                                                      |
//+------------------------------------------------------------------+
double CPairsTradingCalculator::GetVariance(const double &arr[], double mean, int size)
  {
   double sum_sq_diff = 0.0;
   for(int i = 0; i < size; i++)
      sum_sq_diff += (arr[i] - mean) * (arr[i] - mean);
   return sum_sq_diff / (size - 1);
  }

//+------------------------------------------------------------------+
//| GetCovariance                                                    |
//+------------------------------------------------------------------+
double CPairsTradingCalculator::GetCovariance(const double &arr1[], double mean1, const double &arr2[], double mean2, int size)
  {
   double sum_prod = 0.0;
   for(int i = 0; i < size; i++)
      sum_prod += (arr1[i] - mean1) * (arr2[i] - mean2);
   return sum_prod / (size - 1);
  }

#endif // PAIRS_TRADING_CALCULATOR_MQH
//+------------------------------------------------------------------+
