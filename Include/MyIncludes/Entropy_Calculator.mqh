//+------------------------------------------------------------------+
//|                                        Entropy_Calculator.mqh    |
//|      Engine for Sample Entropy (SampEn).                         |
//|      Measures time series complexity/regularity.                 |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.10" // Enterprise: Linear Detrending Mode for Authentic Trend Regularity
#property description "High-performance calculation engine for Sample Entropy (Richman-Moorman)."

#ifndef ENTROPY_CALCULATOR_MQH
#define ENTROPY_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Calculation Modes for Financial Time Series
#ifndef ENUM_ENTROPY_MODE_DEFINED
#define ENUM_ENTROPY_MODE_DEFINED
enum ENUM_ENTROPY_MODE
  {
   ENTROPY_DETRENDED,    // Detrended Residuals (Recommended: Low Entropy in Clean Trends)
   ENTROPY_LOG_RETURNS,  // Log Returns (Measures Return Dispersion Predictability)
   ENTROPY_PRICE_DIFF,   // First Differences (P[t] - P[t-1])
   ENTROPY_RAW_PRICE     // Raw Price (Prone to Drift Distortion)
  };
#endif

//+==================================================================+
//|             CLASS: CEntropyCalculator                            |
//+==================================================================+
class CEntropyCalculator
  {
protected:
   int                m_period;        // Analysis Window (N)
   int                m_dim;           // Embedding Dimension (m, default 2)
   double             m_tolerance;     // Tolerance Threshold (r multiplier, default 0.3)
   ENUM_ENTROPY_MODE  m_mode;          // Stationary Transformation Mode

   //--- Persistent Price Buffers
   double             m_raw_price[];
   double             m_trans_series[];
   double             m_window_buf[];  // Local scratchpad for detrending

   virtual bool       PrepareDataSeries(const int rates_total, const int start_index,
                                        const ENUM_APPLIED_PRICE price_type,
                                        const double &open[], const double &high[],
                                        const double &low[], const double &close[]);

public:
                     CEntropyCalculator(void);
                    ~CEntropyCalculator(void) {};

   bool               Init(const int period, const int dim, const double tolerance_coeff, const ENUM_ENTROPY_MODE mode = ENTROPY_DETRENDED);
   int                GetPeriod(void) const { return m_period; }

   void               Calculate(const int rates_total, const int prev_calculated,
                                const ENUM_APPLIED_PRICE price_type,
                                const double &open[], const double &high[],
                                const double &low[], const double &close[],
                                double &out_entropy[], const int history_limit = 0);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEntropyCalculator::CEntropyCalculator(void) :
   m_period(50),
   m_dim(2),
   m_tolerance(0.3),
   m_mode(ENTROPY_DETRENDED)
  {
   ArraySetAsSeries(m_raw_price,    false);
   ArraySetAsSeries(m_trans_series, false);
   ArraySetAsSeries(m_window_buf,   false);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CEntropyCalculator::Init(const int period, const int dim, const double tolerance_coeff, const ENUM_ENTROPY_MODE mode)
  {
   m_period    = (period < 15) ? 15 : period;
   m_dim       = (dim < 1) ? 2 : dim;
   m_tolerance = (tolerance_coeff <= 0.0) ? 0.3 : tolerance_coeff;
   m_mode      = mode;

   ArrayResize(m_window_buf, m_period);
   ArraySetAsSeries(m_window_buf, false);
   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Price Series & Base Transformations                      |
//+------------------------------------------------------------------+
bool CEntropyCalculator::PrepareDataSeries(const int rates_total, const int start_index,
      const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[],
      const double &low[], const double &close[])
  {
   if(ArraySize(m_raw_price) != rates_total)
     {
      ArrayResize(m_raw_price,    rates_total);
      ArrayResize(m_trans_series, rates_total);
      ArraySetAsSeries(m_raw_price,    false);
      ArraySetAsSeries(m_trans_series, false);
     }

   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_OPEN:
            m_raw_price[i] = open[i];
            break;
         case PRICE_HIGH:
            m_raw_price[i] = high[i];
            break;
         case PRICE_LOW:
            m_raw_price[i] = low[i];
            break;
         case PRICE_MEDIAN:
            m_raw_price[i] = (high[i] + low[i]) * 0.5;
            break;
         case PRICE_TYPICAL:
            m_raw_price[i] = (high[i] + low[i] + close[i]) * 0.333333333333;
            break;
         case PRICE_WEIGHTED:
            m_raw_price[i] = (high[i] + low[i] + 2.0 * close[i]) * 0.25;
            break;
         case PRICE_CLOSE:
         default:
            m_raw_price[i] = close[i];
            break;
        }

      if(m_mode == ENTROPY_LOG_RETURNS)
        {
         m_trans_series[i] = (i > 0 && m_raw_price[i - 1] > 0.0) ? MathLog(m_raw_price[i] / m_raw_price[i - 1]) : 0.0;
        }
      else
         if(m_mode == ENTROPY_PRICE_DIFF)
           {
            m_trans_series[i] = (i > 0) ? (m_raw_price[i] - m_raw_price[i - 1]) : 0.0;
           }
         else
           {
            m_trans_series[i] = m_raw_price[i];
           }
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation Engine (Symmetric O(N^2 / 2) Kernel)            |
//+------------------------------------------------------------------+
void CEntropyCalculator::Calculate(const int rates_total, const int prev_calculated,
                                   const ENUM_APPLIED_PRICE price_type,
                                   const double &open[], const double &high[],
                                   const double &low[], const double &close[],
                                   double &out_entropy[], const int history_limit)
  {
   int warmup = m_period + m_dim + 2;
   if(rates_total < warmup)
      return;

   if(ArraySize(out_entropy) != rates_total)
     {
      ArrayResize(out_entropy, rates_total);
      ArraySetAsSeries(out_entropy, false);
     }

   int start_prep = (prev_calculated > 0) ? (prev_calculated - 1) : 0;
   if(!PrepareDataSeries(rates_total, start_prep, price_type, open, high, low, close))
      return;

   int start = (prev_calculated > 0) ? (prev_calculated - 1) : warmup;
   if(history_limit > 0 && prev_calculated == 0)
     {
      int limit_start = rates_total - history_limit;
      if(limit_start > start)
         start = limit_start;
     }

   if(prev_calculated == 0)
     {
      for(int i = 0; i < start; i++)
         out_entropy[i] = EMPTY_VALUE;
     }

   int N = m_period;
   int m = m_dim;
   int num_vectors = N - m;
   double inv_N = 1.0 / (double)N;

// Precalculated linear regression constants for detrending
   double sum_x = 0.5 * (double)(N - 1) * (double)N;
   double sum_x2 = (double)(N - 1) * (double)N * (double)(2 * N - 1) / 6.0;
   double denom_reg = (double)N * sum_x2 - sum_x * sum_x;
   double inv_denom_reg = (MathAbs(denom_reg) > 1.0e-9) ? (1.0 / denom_reg) : 0.0;

// Main Rolling SampEn Evaluation
   for(int i = start; i < rates_total; i++)
     {
      int win_start = i - N + 1;

      // Extract window data
      if(m_mode == ENTROPY_DETRENDED)
        {
         // 1. O(N) Linear Regression Detrending to isolate pure structural pattern
         double sum_y = 0.0, sum_xy = 0.0;
         for(int k = 0; k < N; k++)
           {
            double y = m_raw_price[win_start + k];
            sum_y  += y;
            sum_xy += (double)k * y;
           }

         double slope = ((double)N * sum_xy - sum_x * sum_y) * inv_denom_reg;
         double intercept = (sum_y - slope * sum_x) * inv_N;

         // Compute residuals (detrended waveform)
         for(int k = 0; k < N; k++)
            m_window_buf[k] = m_raw_price[win_start + k] - (intercept + slope * (double)k);
        }
      else
        {
         for(int k = 0; k < N; k++)
            m_window_buf[k] = m_trans_series[win_start + k];
        }

      // 2. Window Standard Deviation for Dynamic Threshold r
      double sum = 0.0, sum_sq = 0.0;
      for(int k = 0; k < N; k++)
        {
         double val = m_window_buf[k];
         sum    += val;
         sum_sq += val * val;
        }

      double mean     = sum * inv_N;
      double variance = (sum_sq * inv_N) - (mean * mean);
      double std_dev  = (variance > 1.0e-12) ? MathSqrt(variance) : 0.0;

      if(std_dev < 1.0e-9)
        {
         out_entropy[i] = 0.0; // Perfectly regular line
         continue;
        }

      double r = m_tolerance * std_dev;

      // 3. Symmetric Pair Matching (50% ALU reduction)
      int pairs_A = 0; // Length m + 1 matches
      int pairs_B = 0; // Length m matches

      for(int j = 0; j < num_vectors - 1; j++)
        {
         for(int k = j + 1; k < num_vectors; k++)
           {
            bool match_m = true;
            for(int d = 0; d < m; d++)
              {
               if(MathAbs(m_window_buf[j + d] - m_window_buf[k + d]) >= r)
                 {
                  match_m = false;
                  break;
                 }
              }

            if(match_m)
              {
               pairs_B++;
               if(MathAbs(m_window_buf[j + m] - m_window_buf[k + m]) < r)
                  pairs_A++;
              }
           }
        }

      // 4. Regularized Sample Entropy Calculation
      if(pairs_B > 0 && pairs_A > 0)
        {
         out_entropy[i] = -MathLog((double)pairs_A / (double)pairs_B);
        }
      else
         if(pairs_B > 0 && pairs_A == 0)
           {
            // Laplace continuity correction for finite windows
            out_entropy[i] = -MathLog(1.0 / (double)(pairs_B + 1));
           }
         else
           {
            // High disorder fallback
            out_entropy[i] = (i > 0 && out_entropy[i - 1] != EMPTY_VALUE) ? out_entropy[i - 1] : 2.5;
           }
     }
  }

#endif // ENTROPY_CALCULATOR_MQH
//+------------------------------------------------------------------+
