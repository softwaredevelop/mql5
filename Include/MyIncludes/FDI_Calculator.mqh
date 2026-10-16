//+------------------------------------------------------------------+
//|                                            FDI_Calculator.mqh    |
//|      Engine for Fractal Dimension Index (Carlos Sevcik Method).  |
//|      Measures curve complexity (1.0 = Line, 2.0 = Plane).        |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.10" // Enterprise: Added Pure Brownian-Scaled Normalization for Finite Windows
#property description "High-performance calculation engine for Fractal Dimension Index (FDI)."

#ifndef FDI_CALCULATOR_MQH
#define FDI_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Calculation Method Selector
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
//|             CLASS: CFDICalculator                                |
//+==================================================================+
class CFDICalculator
  {
protected:
   int               m_period;
   ENUM_FDI_METHOD   m_method;
   double            m_price[];          // Persistent source price buffer

   // Precalculated invariant constants for ALU pipelining
   double            m_diff_x;           // 1.0 / (N - 1)
   double            m_diff_x_sq;        // (1.0 / (N - 1))^2
   double            m_log_denominator;  // ln(N - 1) or ln(2 * (N - 1))
   double            m_inv_log_denom;    // Reciprocal of denominator

   virtual bool      PreparePriceSeries(const int rates_total, const int start_index,
                                        const ENUM_APPLIED_PRICE price_type,
                                        const double &open[], const double &high[],
                                        const double &low[], const double &close[]);

public:
                     CFDICalculator(void);
   virtual          ~CFDICalculator(void) {};

   bool              Init(const int period, const ENUM_FDI_METHOD method = FDI_NORMALIZED_BROWNIAN);
   int               GetPeriod(void) const { return m_period; }
   double            GetTheoreticalRandomWalkD(void) const;

   void              Calculate(const int rates_total, const int prev_calculated,
                               const ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               double &out_fdi[], const int history_limit = 0);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFDICalculator::CFDICalculator(void) :
   m_period(30),
   m_method(FDI_NORMALIZED_BROWNIAN),
   m_diff_x(0.0),
   m_diff_x_sq(0.0),
   m_log_denominator(1.0),
   m_inv_log_denom(1.0)
  {
   ArraySetAsSeries(m_price, false);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CFDICalculator::Init(const int period, const ENUM_FDI_METHOD method)
  {
   m_period = (period < 10) ? 10 : period;
   m_method = method;

   m_diff_x    = 1.0 / (double)(m_period - 1);
   m_diff_x_sq = m_diff_x * m_diff_x;

   if(m_method == FDI_NORMALIZED_BROWNIAN)
      m_log_denominator = MathLog((double)(m_period - 1));
   else
      m_log_denominator = MathLog(2.0 * (double)(m_period - 1));

   m_inv_log_denom = (m_log_denominator > 1.0e-9) ? (1.0 / m_log_denominator) : 1.0;

   return true;
  }

//+------------------------------------------------------------------+
//| Theoretical Random Walk Dimension for Current Configuration      |
//+------------------------------------------------------------------+
double CFDICalculator::GetTheoreticalRandomWalkD(void) const
  {
   if(m_method == FDI_NORMALIZED_BROWNIAN)
      return 1.50; // Strictly normalized by design

   if(m_method == FDI_CANONICAL_SEVCIK)
      return 1.0 + (0.5 * MathLog((double)(m_period - 1)) / m_log_denominator);

// Legacy Retail
   return 1.0 + ((0.5 * MathLog((double)(m_period - 1)) + MathLog(2.0)) / m_log_denominator);
  }

//+------------------------------------------------------------------+
//| Prepare Price Series                                             |
//+------------------------------------------------------------------+
bool CFDICalculator::PreparePriceSeries(const int rates_total, const int start_index,
                                        const ENUM_APPLIED_PRICE price_type,
                                        const double &open[], const double &high[],
                                        const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false);
     }

   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
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
            m_price[i] = (high[i] + low[i]) * 0.5;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i] + low[i] + close[i]) * 0.333333333333;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i] + low[i] + 2.0 * close[i]) * 0.25;
            break;
         case PRICE_CLOSE:
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CFDICalculator::Calculate(const int rates_total, const int prev_calculated,
                               const ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               double &out_fdi[], const int history_limit)
  {
   if(rates_total < m_period)
      return;

   if(ArraySize(out_fdi) != rates_total)
     {
      ArrayResize(out_fdi, rates_total);
      ArraySetAsSeries(out_fdi, false);
     }

   int start_prep = (prev_calculated > 0) ? (prev_calculated - 1) : 0;
   if(!PreparePriceSeries(rates_total, start_prep, price_type, open, high, low, close))
      return;

   int start_index = (prev_calculated > m_period) ? (prev_calculated - 1) : m_period;
   if(history_limit > 0 && prev_calculated == 0)
     {
      int limit_start = rates_total - history_limit;
      if(limit_start > start_index)
         start_index = limit_start;
     }

   if(prev_calculated == 0)
     {
      for(int i = 0; i < start_index; i++)
         out_fdi[i] = EMPTY_VALUE;
     }

   double ln_2 = MathLog(2.0);

   for(int i = start_index; i < rates_total; i++)
     {
      // 1. Extreme Price Range in window
      double highest = -DBL_MAX;
      double lowest  =  DBL_MAX;
      int win_start  = i - m_period + 1;

      for(int k = 0; k < m_period; k++)
        {
         double p = m_price[win_start + k];
         if(p > highest)
            highest = p;
         if(p < lowest)
            lowest  = p;
        }

      double price_range = highest - lowest;

      // 2. Waveform Path Length (L) in Unit Square
      double path_length = 0.0;

      if(price_range > 1.0e-9)
        {
         double inv_range = 1.0 / price_range;

         for(int k = 1; k < m_period; k++)
           {
            double diff_price = m_price[win_start + k] - m_price[win_start + k - 1];
            double diff_y     = diff_price * inv_range;
            path_length += MathSqrt(m_diff_x_sq + (diff_y * diff_y));
           }
        }
      else
        {
         path_length = 1.0;
        }

      // 3. Normalized Fractal Dimension Calculation
      if(path_length > 1.0e-9)
        {
         double ln_L = MathLog(path_length);

         if(m_method == FDI_NORMALIZED_BROWNIAN)
           {
            // Anchored: Flat Line = 1.0, Brownian Random Walk = 1.50
            out_fdi[i] = 1.0 + (ln_L * m_inv_log_denom);
           }
         else
            if(m_method == FDI_CANONICAL_SEVCIK)
              {
               out_fdi[i] = 1.0 + (ln_L * m_inv_log_denom);
              }
            else
              {
               out_fdi[i] = 1.0 + ((ln_L + ln_2) * m_inv_log_denom);
              }
        }
      else
        {
         out_fdi[i] = 1.0;
        }
     }
  }

#endif // FDI_CALCULATOR_MQH
//+------------------------------------------------------------------+
