//+------------------------------------------------------------------+
//|                               MLRegressionTrend_Calculator.mqh   |
//|        Headless Machine Learning Engine for RANSAC Regression    |
//|               Strict 100% Equivalent of LuxAlgo Pine Script      |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.20" // Enterprise Edition: Multi-Asset Pip & Point Normalized Inlier Thresholds
#property description "Mathematical engine for RANSAC Machine Learning Linear Regression Trend."

#ifndef ML_REGRESSION_TREND_CALCULATOR_MQH
#define ML_REGRESSION_TREND_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Allowed Error Type Options (Pip-Normalized for Multi-Asset Uniformity)
#ifndef ENUM_ERROR_TYPE_DEFINED
#define ENUM_ERROR_TYPE_DEFINED
enum ENUM_ERROR_TYPE
  {
   ERROR_AUTO,        // Auto: Multiplier of Average Candle Body (Scale-Invariant)
   ERROR_FIXED_PIPS,  // Fixed Pips: Auto-normalized across Forex, Metals & Indices
   ERROR_FIXED_PRICE  // Fixed Price: Raw Price Units (for Stocks/Futures)
  };
#endif

//--- Output Structure for RANSAC Regression
struct SRansacResult
  {
   double            slope;             // a: Best regression slope
   double            intercept;         // b: Best regression intercept
   double            threshold;         // Dynamic inlier distance threshold
   double            rmse;              // Root Mean Square Error (on ALL points, as in Pine Script)
   double            channel_width;     // rmse * widthMult
   int               inliers_count;     // Number of consensus inliers found
   int               total_points;      // Window sample length (length)
   double            y_start;           // Line start value (at n - length + 1)
   double            y_end;             // Line end value (at n)
   datetime          t_start;           // Start bar timestamp
   datetime          t_end;             // End bar timestamp
  };

//+==================================================================+
//|   CLASS: CMLRegressionTrend_Calculator                           |
//+==================================================================+
class CMLRegressionTrend_Calculator
  {
private:
   int                       m_length;
   double                    m_width_mult;
   int                       m_min_inliers;
   ENUM_ERROR_TYPE           m_error_type;
   double                    m_min_error;
   int                       m_max_iter;
   ENUM_APPLIED_PRICE_HA_ALL m_source_type;

   // Persistent Price & Accumulator Buffers
   double                    m_price[];
   double                    m_cum_body[]; // Persistent ta.cum(abs(close - open)) equivalent

   // Working Buffers for Local Window
   double                    m_win_y[];
   bool                      m_best_inliers_mask[];
   bool                      m_curr_mask[];
   datetime                  m_win_times[];

   // Heikin Ashi Buffers
   double                    m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];
   CHeikinAshi_Calculator    m_ha_engine;

   // Processed Output
   SRansacResult             m_result;

   bool                      PrepareData(const int rates_total, const int start_index,
                                         const double &open[], const double &high[],
                                         const double &low[], const double &close[]);

public:
                     CMLRegressionTrend_Calculator(void);
                    ~CMLRegressionTrend_Calculator(void);

   bool                      Init(const int length, const double width_mult, const int min_inliers,
                                  const ENUM_ERROR_TYPE error_type, const double min_error,
                                  const int max_iter, const ENUM_APPLIED_PRICE_HA_ALL source);

   bool                      Execute(const int rates_total, const int prev_calculated,
                                     const datetime &time[], const double &open[],
                                     const double &high[], const double &low[], const double &close[]);

   bool                      GetResult(SRansacResult &out_res) const;
   bool                      IsInlier(const int window_k) const;
   double                    GetWindowPrice(const int window_k) const;
   datetime                  GetWindowTime(const int window_k) const;
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMLRegressionTrend_Calculator::CMLRegressionTrend_Calculator(void) :
   m_length(100),
   m_width_mult(2.0),
   m_min_inliers(10),
   m_error_type(ERROR_AUTO),
   m_min_error(1.0),
   m_max_iter(150),
   m_source_type(PRICE_CLOSE_STD)
  {
   ArraySetAsSeries(m_price,             false);
   ArraySetAsSeries(m_cum_body,          false);
   ArraySetAsSeries(m_win_y,             false);
   ArraySetAsSeries(m_best_inliers_mask, false);
   ArraySetAsSeries(m_curr_mask,         false);
   ArraySetAsSeries(m_win_times,         false);
   ArraySetAsSeries(m_ha_open,           false);
   ArraySetAsSeries(m_ha_high,           false);
   ArraySetAsSeries(m_ha_low,            false);
   ArraySetAsSeries(m_ha_close,          false);
   ZeroMemory(m_result);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMLRegressionTrend_Calculator::~CMLRegressionTrend_Calculator(void)
  {
   ArrayFree(m_price);
   ArrayFree(m_cum_body);
   ArrayFree(m_win_y);
   ArrayFree(m_best_inliers_mask);
   ArrayFree(m_curr_mask);
   ArrayFree(m_win_times);
   ArrayFree(m_ha_open);
   ArrayFree(m_ha_high);
   ArrayFree(m_ha_low);
   ArrayFree(m_ha_close);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CMLRegressionTrend_Calculator::Init(const int length, const double width_mult, const int min_inliers,
      const ENUM_ERROR_TYPE error_type, const double min_error,
      const int max_iter, const ENUM_APPLIED_PRICE_HA_ALL source)
  {
   m_length      = (length < 5) ? 5 : length;
   m_width_mult  = (width_mult <= 0.0) ? 2.0 : width_mult;
   m_min_inliers = (min_inliers < 1) ? 1 : min_inliers;
   m_error_type  = error_type;
   m_min_error   = (min_error <= 0.0) ? 1.0 : min_error;
   m_max_iter    = MathMin(MathMax(max_iter, 50), 2000);
   m_source_type = source;

   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Price Series & ta.cum Running Accumulator                |
//+------------------------------------------------------------------+
bool CMLRegressionTrend_Calculator::PrepareData(const int rates_total, const int start_index,
      const double &open[], const double &high[],
      const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price,    rates_total, 2048);
      ArrayResize(m_cum_body, rates_total, 2048);
      ArraySetAsSeries(m_price,    false);
      ArraySetAsSeries(m_cum_body, false);
     }

   bool is_ha = (m_source_type <= PRICE_HA_CLOSE);

   if(is_ha)
     {
      if(ArraySize(m_ha_open) != rates_total)
        {
         ArrayResize(m_ha_open,  rates_total, 2048);
         ArrayResize(m_ha_high,  rates_total, 2048);
         ArrayResize(m_ha_low,   rates_total, 2048);
         ArrayResize(m_ha_close, rates_total, 2048);
         ArraySetAsSeries(m_ha_open,  false);
         ArraySetAsSeries(m_ha_high,  false);
         ArraySetAsSeries(m_ha_low,   false);
         ArraySetAsSeries(m_ha_close, false);
        }

      m_ha_engine.Calculate(rates_total, start_index, open, high, low, close,
                            m_ha_open, m_ha_high, m_ha_low, m_ha_close);

      for(int i = start_index; i < rates_total; i++)
        {
         switch(m_source_type)
           {
            case PRICE_HA_OPEN:
               m_price[i] = m_ha_open[i];
               break;
            case PRICE_HA_HIGH:
               m_price[i] = m_ha_high[i];
               break;
            case PRICE_HA_LOW:
               m_price[i] = m_ha_low[i];
               break;
            case PRICE_HA_MEDIAN:
               m_price[i] = (m_ha_high[i] + m_ha_low[i]) * 0.5;
               break;
            case PRICE_HA_TYPICAL:
               m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) * 0.333333333333;
               break;
            case PRICE_HA_WEIGHTED:
               m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) * 0.25;
               break;
            case PRICE_HA_CLOSE:
            default:
               m_price[i] = m_ha_close[i];
               break;
           }

         double body = MathAbs(close[i] - open[i]);
         m_cum_body[i] = (i == 0) ? body : (m_cum_body[i - 1] + body);
        }
     }
   else
     {
      for(int i = start_index; i < rates_total; i++)
        {
         switch(m_source_type)
           {
            case PRICE_OPEN_STD:
               m_price[i] = open[i];
               break;
            case PRICE_HIGH_STD:
               m_price[i] = high[i];
               break;
            case PRICE_LOW_STD:
               m_price[i] = low[i];
               break;
            case PRICE_MEDIAN_STD:
               m_price[i] = (high[i] + low[i]) * 0.5;
               break;
            case PRICE_TYPICAL_STD:
               m_price[i] = (high[i] + low[i] + close[i]) * 0.333333333333;
               break;
            case PRICE_WEIGHTED_STD:
               m_price[i] = (high[i] + low[i] + 2.0 * close[i]) * 0.25;
               break;
            case PRICE_CLOSE_STD:
            default:
               m_price[i] = close[i];
               break;
           }

         double body = MathAbs(close[i] - open[i]);
         m_cum_body[i] = (i == 0) ? body : (m_cum_body[i - 1] + body);
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Core Execution: Exact LuxAlgo Pine Script Algorithm              |
//+------------------------------------------------------------------+
bool CMLRegressionTrend_Calculator::Execute(const int rates_total, const int prev_calculated,
      const datetime &time[], const double &open[],
      const double &high[], const double &low[], const double &close[])
  {
   int len = m_length;
   if(rates_total < len)
      return false;

   if(ArraySize(m_win_y) != len)
     {
      ArrayResize(m_win_y,             len);
      ArrayResize(m_best_inliers_mask, len);
      ArrayResize(m_curr_mask,         len);
      ArrayResize(m_win_times,         len);
      ArraySetAsSeries(m_win_y,             false);
      ArraySetAsSeries(m_best_inliers_mask, false);
      ArraySetAsSeries(m_curr_mask,         false);
      ArraySetAsSeries(m_win_times,         false);
     }

   int start_prep = (prev_calculated > 0) ? (prev_calculated - 1) : 0;
   if(!PrepareData(rates_total, start_prep, open, high, low, close))
      return false;

   int win_start = rates_total - len;

// 1. Calculate Threshold with Normalized Pip/Tick Awareness
   double threshold = m_min_error;

   if(m_error_type == ERROR_AUTO)
     {
      double lifetime_avg_body = m_cum_body[rates_total - 1] / (double)rates_total;
      threshold = lifetime_avg_body * m_min_error;
     }
   else
      if(m_error_type == ERROR_FIXED_PIPS)
        {
         // Convert Pips to physical Price Units across all instruments
         double pip_size = (_Digits == 3 || _Digits == 5) ? 10.0 * _Point : _Point;
         threshold = m_min_error * pip_size;
        }
      else // ERROR_FIXED_PRICE
        {
         threshold = m_min_error; // Raw price units
        }

   if(threshold <= 0.0)
      threshold = _Point;

// 2. Mirror local window data
   for(int k = 0; k < len; k++)
     {
      m_win_y[k]     = m_price[win_start + k];
      m_win_times[k] = time[win_start + k];
     }

// 3. DETERMINISTIC PRNG SEEDING:
   uint deterministic_seed = (uint)time[win_start] ^ 0xA5A5A5A5;
   MathSrand(deterministic_seed);

// 4. Exact LuxAlgo RANSAC Loop
   int size = m_min_inliers;
   double best_a = 0.0, best_b = 0.0;
   bool model_found = false;

   ArrayInitialize(m_best_inliers_mask, false);

   for(int iter = 0; iter < m_max_iter; iter++)
     {
      int idx1 = (int)(MathRand() % len);
      int idx2 = (int)(MathRand() % len);
      if(idx1 == idx2)
         continue;

      double y1 = m_win_y[idx1];
      double y2 = m_win_y[idx2];
      double x1 = (double)idx1;
      double x2 = (double)idx2;

      double a_cand = (y2 - y1) / (x2 - x1);
      double b_cand = y1 - a_cand * x1;

      int inliers_count = 0;
      for(int k = 0; k < len; k++)
        {
         double pred = a_cand * (double)k + b_cand;
         if(MathAbs(m_win_y[k] - pred) < threshold)
           {
            m_curr_mask[k] = true;
            inliers_count++;
           }
         else
           {
            m_curr_mask[k] = false;
           }
        }

      if(inliers_count >= size)
        {
         double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;
         for(int k = 0; k < len; k++)
           {
            if(m_curr_mask[k])
              {
               double x_val = (double)k;
               double y_val = m_win_y[k];
               sum_x  += x_val;
               sum_y  += y_val;
               sum_xy += x_val * y_val;
               sum_x2 += x_val * x_val;
              }
           }

         double m_count = (double)inliers_count;
         double var_x = sum_x2 - (sum_x * sum_x) / m_count;

         if(var_x > 1.0e-12)
           {
            double cov_xy = sum_xy - (sum_x * sum_y) / m_count;
            best_a = cov_xy / var_x;
            best_b = (sum_y - best_a * sum_x) / m_count;

            model_found = true;
            ArrayCopy(m_best_inliers_mask, m_curr_mask);

            size = inliers_count;
           }
        }
     }

// Fallback: OLS across entire window
   if(!model_found)
     {
      double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;
      for(int k = 0; k < len; k++)
        {
         double x_val = (double)k;
         double y_val = m_win_y[k];
         sum_x  += x_val;
         sum_y  += y_val;
         sum_xy += x_val * y_val;
         sum_x2 += x_val * x_val;
        }

      double m_count = (double)len;
      double var_x = sum_x2 - (sum_x * sum_x) / m_count;
      if(var_x > 1.0e-12)
        {
         best_a = (sum_xy - (sum_x * sum_y) / m_count) / var_x;
         best_b = (sum_y - best_a * sum_x) / m_count;
         for(int k = 0; k < len; k++)
            m_best_inliers_mask[k] = (MathAbs(m_win_y[k] - (best_a * (double)k + best_b)) < threshold);
         size = len;
        }
     }

// 5. Calculate RMSE on ALL POINTS in window
   double sum_sq_err = 0.0;
   for(int k = 0; k < len; k++)
     {
      double pred = best_a * (double)k + best_b;
      double err  = m_win_y[k] - pred;
      sum_sq_err += err * err;
     }

   double rmse = MathSqrt(sum_sq_err / (double)len);

// Populate Output Result Structure
   m_result.slope         = best_a;
   m_result.intercept     = best_b;
   m_result.threshold     = threshold;
   m_result.rmse          = rmse;
   m_result.channel_width = rmse * m_width_mult;
   m_result.inliers_count = size;
   m_result.total_points  = len;
   m_result.y_start       = best_b;
   m_result.y_end         = best_a * (double)(len - 1) + best_b;
   m_result.t_start       = time[win_start];
   m_result.t_end         = time[rates_total - 1];

   return true;
  }

//+------------------------------------------------------------------+
//| Accessor Methods                                                 |
//+------------------------------------------------------------------+
bool CMLRegressionTrend_Calculator::GetResult(SRansacResult &out_res) const
  {
   if(m_result.total_points <= 0)
      return false;
   out_res = m_result;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMLRegressionTrend_Calculator::IsInlier(const int window_k) const
  {
   if(window_k >= 0 && window_k < m_length)
      return m_best_inliers_mask[window_k];
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CMLRegressionTrend_Calculator::GetWindowPrice(const int window_k) const
  {
   if(window_k >= 0 && window_k < m_length)
      return m_win_y[window_k];
   return 0.0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime CMLRegressionTrend_Calculator::GetWindowTime(const int window_k) const
  {
   if(window_k >= 0 && window_k < m_length)
      return m_win_times[window_k];
   return 0;
  }

#endif // ML_REGRESSION_TREND_CALCULATOR_MQH
//+------------------------------------------------------------------+
