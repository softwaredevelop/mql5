//+------------------------------------------------------------------+
//|                                     PairsTrading_Calculator.mqh  |
//|      Engine for Dynamic Rolling/Anchored OLS Pairs Cointegration |
//|      Strictly O(1) Incremental Optimized.                        |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Added support for dynamic anchored window sizes

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

   //--- Statistics helpers
   double            GetMean(const double &arr[], int size);
   double            GetVariance(const double &arr[], double mean, int size);
   double            GetCovariance(const double &arr1[], double mean1, const double &arr2[], double mean2, int size);

public:
                     CPairsTradingCalculator();
                    ~CPairsTradingCalculator() {};

   bool              Init(int max_window);

   //--- Upgraded: Accepts a dynamic window_size for VWAP-style anchored resets
   double            CalculateZScore(int rates_total, int current_index, int window_size,
                                     const double &sync_price_A[], const double &sync_price_B[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPairsTradingCalculator::CPairsTradingCalculator() : m_max_window(120) {}

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
// Safety 1: Enforce minimum of 15 bars for statistical significance on anchored starts
   if(window_size < 15 || current_index < window_size)
      return 0.0;

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
      return 0.0; // Div-by-zero protection

//--- Calculate OLS Rolling Hedge Ratio (Beta) and Intercept (Alpha)
   double beta  = cov_AB / var_B;
   double alpha = mean_A - (beta * mean_B);

//--- Calculate the historical spreads over the active window (Mean is algebraically 0.0)
   double sum_sq_spread = 0.0;
   for(int k = 0; k < window_size; k++)
     {
      m_spread_history[k] = m_arr_A[k] - (beta * m_arr_B[k]) - alpha;
      sum_sq_spread += m_spread_history[k] * m_spread_history[k];
     }

// Sample standard deviation of the active spread window
   double std_dev_spread = MathSqrt(sum_sq_spread / (window_size - 1));

   if(std_dev_spread <= 1.0e-9)
      return 0.0; // Protection against dead spreads

//--- Calculate the final current Z-Score
   double current_spread = sync_price_A[current_index] - (beta * sync_price_B[current_index]) - alpha;

   return current_spread / std_dev_spread;
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
