//+------------------------------------------------------------------+
//|                                    MathStatistics_Calculator.mqh |
//|      Engine for Financial Statistics (Beta, Alpha, Correlation). |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CMathStatisticsCalculator
  {
public:
                     CMathStatisticsCalculator() {};
                    ~CMathStatisticsCalculator() {};

   //--- Calculate Beta (Sensitivity to Benchmark)
   // Beta = Covariance(Asset, Bench) / Variance(Bench)
   double            CalculateBeta(const double &asset_returns[], const double &bench_returns[])
     {
      int n = MathMin(ArraySize(asset_returns), ArraySize(bench_returns));
      if(n < 2)
         return 0.0; // Need at least 2 points

      double mean_asset = Mean(asset_returns, n);
      double mean_bench = Mean(bench_returns, n);

      double cov = Covariance(asset_returns, mean_asset, bench_returns, mean_bench, n);
      double var = Variance(bench_returns, mean_bench, n);

      if(var == 0.0)
         return 0.0;
      return cov / var;
     }

   //--- Calculate Alpha (Excess Return)
   // Alpha = AssetReturn - (Beta * BenchReturn)
   // Usually calculated over a period based on cumulative return or average return
   // Here we calculate Period Alpha (Total Return logic)
   double            CalculateAlpha(double asset_total_return, double bench_total_return, double beta)
     {
      return asset_total_return - (beta * bench_total_return);
     }

   //--- Helpers
   double            Mean(const double &arr[], int n)
     {
      double sum = 0;
      for(int i=0; i<n; i++)
         sum += arr[i];
      return sum / n;
     }

   double            Variance(const double &arr[], double mean, int n)
     {
      double sum_sq_diff = 0;
      for(int i=0; i<n; i++)
         sum_sq_diff += MathPow(arr[i] - mean, 2);
      return sum_sq_diff / (n - 1); // Sample Variance
     }

   double            Covariance(const double &arr1[], double mean1, const double &arr2[], double mean2, int n)
     {
      double sum_prod = 0;
      for(int i=0; i<n; i++)
         sum_prod += (arr1[i] - mean1) * (arr2[i] - mean2);
      return sum_prod / (n - 1);
     }

   // Helper to compute log returns from price array
   // Returns array size will be price_size - 1
   void              ComputeReturns(const double &prices[], double &out_returns[])
     {
      int total = ArraySize(prices);
      if(total < 2)
        {
         ArrayResize(out_returns, 0);
         return;
        }

      ArrayResize(out_returns, total - 1);
      for(int i=1; i<total; i++)
        {
         if(prices[i-1] != 0)
            out_returns[i-1] = MathLog(prices[i] / prices[i-1]); // Log Return
         else
            out_returns[i-1] = 0.0;
        }
     }
  };
//+------------------------------------------------------------------+
