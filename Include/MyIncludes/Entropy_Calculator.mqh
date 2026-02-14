//+------------------------------------------------------------------+
//|                                        Entropy_Calculator.mqh    |
//|      Engine for Sample Entropy (SampEn).                         |
//|      Measures time series complexity/regularity.                 |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CEntropyCalculator
  {
protected:
   int               m_period;     // Analysis Window (N)
   int               m_dim;        // Embedding Dimension (m, usually 2)
   double            m_tolerance;  // Tolerance Threshold (r, usually 0.2 * StdDev)

   double            m_price[];    // Buffer

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CEntropyCalculator() : m_period(50), m_dim(2), m_tolerance(0.2) {};
                    ~CEntropyCalculator() {};

   bool              Init(int period, int dim, double tolerance_coeff);

   // Calculates SampEn for the rolling window
   // Requires O(Period^2) ops per bar. Keep Period < 200 for speed.
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &out_entropy[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CEntropyCalculator::Init(int period, int dim, double tolerance_coeff)
  {
   m_period    = (period < 10) ? 10 : period;
   m_dim       = (dim < 1) ? 2 : dim;
   m_tolerance = (tolerance_coeff <= 0) ? 0.2 : tolerance_coeff;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CEntropyCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                   const double &open[], const double &high[], const double &low[], const double &close[],
                                   double &out_entropy[])
  {
   if(rates_total < m_period + 1)
      return;

   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);

   int start_prep = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(!PreparePriceSeries(rates_total, start_prep, price_type, open, high, low, close))
      return;

   int start = (prev_calculated > m_period) ? prev_calculated - 1 : m_period;

// SampEn Algorithm
// We iterate through history. For each bar 'i', we look at window [i-period+1 ... i]

   for(int i = start; i < rates_total; i++)
     {
      // 1. Extract Window & Normalize (Standardize)
      // SampEn depends on 'r' which is r_coeff * StdDev.
      // So we need StdDev of the current window.

      double sum = 0, sum_sq = 0;
      for(int k=0; k<m_period; k++)
        {
         double val = m_price[i-k];
         sum += val;
         sum_sq += val*val;
        }
      double mean = sum / m_period;
      double variance = (sum_sq - (sum*sum)/m_period) / m_period; // Population var
      double std_dev = MathSqrt(variance);

      // Threshold r
      double r = m_tolerance * std_dev;

      if(std_dev < 1.0e-9)
        {
         out_entropy[i] = 0;   // Flat line = 0 entropy
         continue;
        }

      // 2. Count Matches for m (B) and m+1 (A)
      // Logic: Compare vectors X_m(j) with X_m(k) inside the window
      // Window indices: 0 to N-1 (mapped to i-N+1 ... i)

      double count_A = 0; // Matches for m+1
      double count_B = 0; // Matches for m

      // We loop j from 0 to N-m-1
      // We loop k from 0 to N-m-1, k != j
      // Optimization: Calculate diffs on standardized data or use 'r' directly on price diffs.
      // We use raw price diffs < r.

      int N = m_period;
      int m = m_dim;

      for(int j=0; j < N-m; j++)
        {
         for(int k=0; k < N-m; k++)
           {
            if(j == k)
               continue; // Self-match exclusion (SampEn specific)

            // Check max distance (Chebyshev) for length m
            bool match_m = true;
            for(int d=0; d<m; d++)
              {
               // Using indices relative to the window START
               // Window Start Index in Price array: start_idx = i - N + 1
               int p_j = i - N + 1 + j + d;
               int p_k = i - N + 1 + k + d;

               if(MathAbs(m_price[p_j] - m_price[p_k]) >= r)
                 {
                  match_m = false;
                  break;
                 }
              }

            if(match_m)
              {
               count_B++; // Found match for length m

               // Check if it extends to m+1
               int p_j_next = i - N + 1 + j + m;
               int p_k_next = i - N + 1 + k + m;

               // Safety check for array bound (though loop limit N-m ensures m+1 exists if j < N-m)
               // N-m is limit. Max j is N-m-1. Max index accessed is N-m-1 + m = N-1. (Last element). Safe.

               if(MathAbs(m_price[p_j_next] - m_price[p_k_next]) < r)
                 {
                  count_A++;
                 }
              }
           }
        }

      if(count_B > 0 && count_A > 0)
        {
         out_entropy[i] = -MathLog(count_A / count_B);
        }
      else
        {
         out_entropy[i] = (i>0) ? out_entropy[i-1] : 2.5;
         // SampEn for random usually around 2.0-2.5 for m=2
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price                                                    |
//+------------------------------------------------------------------+
bool CEntropyCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = high[i];
            break;
         case PRICE_LOW:
            m_price[i] = low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (high[i]+low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
