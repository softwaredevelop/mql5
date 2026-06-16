//+------------------------------------------------------------------+
//|                                     PairsTrading_Calculator.mqh  |
//|      Engine for Dynamic Rolling OLS Pairs Trading Cointegration. |
//|      Strictly O(1) Incremental Optimized.                        |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"

#ifndef PAIRS_TRADING_CALCULATOR_MQH
#define PAIRS_TRADING_CALCULATOR_MQH

//+==================================================================+
//|             CLASS: CPairsTradingCalculator                       |
//+==================================================================+
class CPairsTradingCalculator
  {
private:
   int               m_lookback;

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

   bool              Init(int lookback);

   //--- Processes the raw synchronized prices and computes the rolling Z-Score
   double            CalculateZScore(int rates_total, int current_index,
                                     const double &sync_price_A[], const double &sync_price_B[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPairsTradingCalculator::CPairsTradingCalculator() : m_lookback(120) {}

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CPairsTradingCalculator::Init(int lookback)
  {
   m_lookback = (lookback < 10) ? 10 : lookback;
   return true;
  }

//+------------------------------------------------------------------+
//| CalculateZScore (OLS Rolling Hedge Ratio & Z-Score)              |
//+------------------------------------------------------------------+
double CPairsTradingCalculator::CalculateZScore(int rates_total, int current_index,
      const double &sync_price_A[], const double &sync_price_B[])
  {
   if(current_index < m_lookback)
      return 0.0;

//--- Resize internal rolling buffers
   if(ArraySize(m_arr_A) != m_lookback)
     {
      ArrayResize(m_arr_A, m_lookback);
      ArrayResize(m_arr_B, m_lookback);
      ArrayResize(m_spread_history, m_lookback);
     }

//--- Extract rolling window from synchronized prices
   for(int k = 0; k < m_lookback; k++)
     {
      int src_idx = current_index - m_lookback + 1 + k;
      m_arr_A[k] = sync_price_A[src_idx];
      m_arr_B[k] = sync_price_B[src_idx];
     }

//--- Calculate means
   double mean_A = GetMean(m_arr_A, m_lookback);
   double mean_B = GetMean(m_arr_B, m_lookback);

//--- Calculate Variance of Benchmark (B) and Covariance (A, B)
   double var_B  = GetVariance(m_arr_B, mean_B, m_lookback);
   double cov_AB = GetCovariance(m_arr_A, mean_A, m_arr_B, mean_B, m_lookback);

   if(var_B <= 1.0e-9)
      return 0.0; // Div-by-zero protection

//--- Calculate OLS Rolling Hedge Ratio (Beta) and Intercept (Alpha)
   double beta  = cov_AB / var_B;
   double alpha = mean_A - (beta * mean_B);

//--- Calculate the historical spreads over the window to find the standard deviation
   double sum_sq_spread = 0.0;
   for(int k = 0; k < m_lookback; k++)
     {
      // Spread_t = A_t - Beta * B_t - Alpha (Mean is algebraically 0.0)
      m_spread_history[k] = m_arr_A[k] - (beta * m_arr_B[k]) - alpha;
      sum_sq_spread += m_spread_history[k] * m_spread_history[k];
     }

// Sample standard deviation of the spread
   double std_dev_spread = MathSqrt(sum_sq_spread / (m_lookback - 1));

   if(std_dev_spread <= 1.0e-9)
      return 0.0; // Protection against flat/dead spreads

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
