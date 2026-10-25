//+------------------------------------------------------------------+
//|                                               Fractal_Engine.mqh |
//|        Universal Calculation Engine for Fractal Geometry,        |
//|        Sevcik Waveform Dimension & Hurst Exponent Dynamics       |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "1.00" // Enterprise Edition: Unified Mathematical Engine for Fractal Geometry
#property description "Core DSP engine for Fractal Dimension, Chaos Ratio, and Hurst Exponent calculations."

#ifndef FRACTAL_ENGINE_MQH
#define FRACTAL_ENGINE_MQH

//--- Method Enumeration for Fractal Dimension Scaling
#ifndef ENUM_FDI_METHOD_DEFINED
#define ENUM_FDI_METHOD_DEFINED
enum ENUM_FDI_METHOD
  {
   FDI_NORMALIZED_BROWNIAN, // Pure Brownian Scale (D = 1.50 at Random Walk for ANY N - Recommended)
   FDI_CANONICAL_SEVCIK,    // Unbiased Sevcik 1998 (D ~ 1.25-1.28 for N=30)
   FDI_RETAIL_CLASSIC       // Legacy Retail Approximation (with +ln(2) numerator shift)
  };
#endif

//+==================================================================+
//|             CLASS: CFractalEngine                                |
//+==================================================================+
class CFractalEngine
  {
private:
   int               m_period;
   ENUM_FDI_METHOD   m_method;

   // Precalculated ALU Invariants
   double            m_diff_x;
   double            m_diff_x_sq;
   double            m_log_denom;
   double            m_inv_log_denom;

public:
                     CFractalEngine(void);
                    ~CFractalEngine(void) {};

   bool              Init(const int period, const ENUM_FDI_METHOD method = FDI_NORMALIZED_BROWNIAN);
   int               GetPeriod(void) const { return m_period; }

   // Pure Point-by-Point Evaluation Kernels (O(Period) execution)
   double            CalculatePathLength(const int idx, const int length, const double &price_series[]) const;
   double            CalculateFDIPoint(const int idx, const int length, const double &price_series[]) const;
   double            CalculateChaosPoint(const int idx, const int length, const double &price_series[]) const;
   double            CalculateHurstPoint(const int idx, const int length, const double &price_series[]) const;

   double            GetTheoreticalRandomWalkD(void) const;
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFractalEngine::CFractalEngine(void) :
   m_period(30),
   m_method(FDI_NORMALIZED_BROWNIAN),
   m_diff_x(0.0),
   m_diff_x_sq(0.0),
   m_log_denom(1.0),
   m_inv_log_denom(1.0)
  {
  }

//+------------------------------------------------------------------+
//| Initialization (Precomputes Coordinate Stepping & Denominators)  |
//+------------------------------------------------------------------+
bool CFractalEngine::Init(const int period, const ENUM_FDI_METHOD method)
  {
   m_period = (period < 5) ? 5 : period;
   m_method = method;

   m_diff_x    = 1.0 / (double)(m_period - 1);
   m_diff_x_sq = m_diff_x * m_diff_x;

   if(m_method == FDI_NORMALIZED_BROWNIAN)
      m_log_denom = MathLog((double)(m_period - 1));
   else
      m_log_denom = MathLog(2.0 * (double)(m_period - 1));

   m_inv_log_denom = (m_log_denom > 1.0e-9) ? (1.0 / m_log_denom) : 1.0;

   return true;
  }

//+------------------------------------------------------------------+
//| Theoretical Random Walk Dimension Baseline                       |
//+------------------------------------------------------------------+
double CFractalEngine::GetTheoreticalRandomWalkD(void) const
  {
   if(m_method == FDI_NORMALIZED_BROWNIAN)
      return 1.50;

   if(m_method == FDI_CANONICAL_SEVCIK)
      return 1.0 + (0.5 * MathLog((double)(m_period - 1)) * m_inv_log_denom);

   return 1.0 + ((0.5 * MathLog((double)(m_period - 1)) + MathLog(2.0)) * m_inv_log_denom);
  }

//+------------------------------------------------------------------+
//| Compute Waveform Path Length in the Unit Square [0, 1] x [0, 1]  |
//+------------------------------------------------------------------+
double CFractalEngine::CalculatePathLength(const int idx, const int length, const double &price_series[]) const
  {
   if(idx < length - 1)
      return 1.0;

   int win_start = idx - length + 1;
   double max_val = price_series[win_start];
   double min_val = price_series[win_start];

   for(int k = 1; k < length; k++)
     {
      double p = price_series[win_start + k];
      if(p > max_val)
         max_val = p;
      if(p < min_val)
         min_val = p;
     }

   double price_range = max_val - min_val;
   if(price_range <= 1.0e-9)
      return 1.0; // Flat straight line

   double inv_range = 1.0 / price_range;
   double path_length = 0.0;

   for(int k = 1; k < length; k++)
     {
      double diff_y = (price_series[win_start + k] - price_series[win_start + k - 1]) * inv_range;
      path_length += MathSqrt(m_diff_x_sq + (diff_y * diff_y));
     }

   return (path_length > 1.0e-9) ? path_length : 1.0e-9;
  }

//+------------------------------------------------------------------+
//| Compute Fractal Dimension D [1.0, 2.0] at a Specific Point       |
//+------------------------------------------------------------------+
double CFractalEngine::CalculateFDIPoint(const int idx, const int length, const double &price_series[]) const
  {
   double path_length = CalculatePathLength(idx, length, price_series);
   double ln_L = MathLog(path_length);

   if(m_method == FDI_NORMALIZED_BROWNIAN)
      return 1.0 + (ln_L * m_inv_log_denom);

   if(m_method == FDI_CANONICAL_SEVCIK)
      return 1.0 + (ln_L * m_inv_log_denom);

// Legacy Retail
   return 1.0 + ((ln_L + MathLog(2.0)) * m_inv_log_denom);
  }

//+------------------------------------------------------------------+
//| Compute Normalized Chaos Ratio [0.0, 1.0] (For Adaptive Filters) |
//+------------------------------------------------------------------+
double CFractalEngine::CalculateChaosPoint(const int idx, const int length, const double &price_series[]) const
  {
   double fdi = CalculateFDIPoint(idx, length, price_series);
   double chaos = (fdi - 1.0) / 0.5;
   return MathMax(0.0, MathMin(1.0, chaos));
  }

//+------------------------------------------------------------------+
//| Compute Hurst Exponent H = 2.0 - D [0.0, 1.0]                    |
//+------------------------------------------------------------------+
double CFractalEngine::CalculateHurstPoint(const int idx, const int length, const double &price_series[]) const
  {
   double fdi = CalculateFDIPoint(idx, length, price_series);
   return MathMax(0.0, MathMin(1.0, 2.0 - fdi));
  }

#endif // FRACTAL_ENGINE_MQH
//+------------------------------------------------------------------+
