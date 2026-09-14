//+------------------------------------------------------------------+
//|                                         RVScore_Calculator.mqh   |
//|      Engine for Rolling Volume-Weighted Z-Score (RV-Score)       |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"

#ifndef RVSCORE_CALCULATOR_MQH
#define RVSCORE_CALCULATOR_MQH

#include <MyIncludes\Rolling_VWAP_Calculator.mqh>

//+==================================================================+
//| CLASS: CRVScoreCalculator                                        |
//| Continuous Statistical Dispersion Engine around Rolling VWAP     |
//+==================================================================+
class CRVScoreCalculator
  {
protected:
   int                     m_sigma_period;
   CRollingVWAPCalculator *m_rolling_vwap_calc;

   // Persistent Buffers for State Preservation
   double                  m_vwap_buf[];
   double                  m_diff_sq_buf[];

public:
                     CRVScoreCalculator(void);
   virtual                ~CRVScoreCalculator(void);

   bool                    Init(const int sigma_period,
                                const ENUM_ROLLING_TYPE rolling_type,
                                const int rolling_window,
                                const ENUM_APPLIED_VOLUME vol_type,
                                const bool is_heikin_ashi = false);

   void                    Calculate(const int rates_total,
                                     const int prev_calculated,
                                     const datetime &time[],
                                     const double &open[],
                                     const double &high[],
                                     const double &low[],
                                     const double &close[],
                                     const long &tick_volume[],
                                     const long &volume[],
                                     double &out_rvscore[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRVScoreCalculator::CRVScoreCalculator(void) :
   m_sigma_period(20),
   m_rolling_vwap_calc(NULL)
  {
   ArraySetAsSeries(m_vwap_buf,    false);
   ArraySetAsSeries(m_diff_sq_buf, false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRVScoreCalculator::~CRVScoreCalculator(void)
  {
   if(CheckPointer(m_rolling_vwap_calc) != POINTER_INVALID)
     {
      delete m_rolling_vwap_calc;
      m_rolling_vwap_calc = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Engine Initialization                                            |
//+------------------------------------------------------------------+
bool CRVScoreCalculator::Init(const int sigma_period,
                              const ENUM_ROLLING_TYPE rolling_type,
                              const int rolling_window,
                              const ENUM_APPLIED_VOLUME vol_type,
                              const bool is_heikin_ashi)
  {
   m_sigma_period = (sigma_period < 2) ? 2 : sigma_period;

   if(CheckPointer(m_rolling_vwap_calc) != POINTER_INVALID)
     {
      delete m_rolling_vwap_calc;
      m_rolling_vwap_calc = NULL;
     }

   if(is_heikin_ashi)
      m_rolling_vwap_calc = new CRollingVWAPCalculator_HA();
   else
      m_rolling_vwap_calc = new CRollingVWAPCalculator();

   if(CheckPointer(m_rolling_vwap_calc) == POINTER_INVALID)
      return false;

   return m_rolling_vwap_calc.Init(rolling_type, rolling_window, vol_type, true);
  }

//+------------------------------------------------------------------+
//| Incremental Dispersion Calculation (O(1))                        |
//+------------------------------------------------------------------+
void CRVScoreCalculator::Calculate(const int rates_total,
                                   const int prev_calculated,
                                   const datetime &time[],
                                   const double &open[],
                                   const double &high[],
                                   const double &low[],
                                   const double &close[],
                                   const long &tick_volume[],
                                   const long &volume[],
                                   double &out_rvscore[])
  {
   if(rates_total < 2 || CheckPointer(m_rolling_vwap_calc) == POINTER_INVALID)
      return;

// 1. Safe Allocation of Internal Registers
   if(ArraySize(m_vwap_buf) != rates_total)
     {
      ArrayResize(m_vwap_buf,    rates_total);
      ArrayResize(m_diff_sq_buf, rates_total);
      ArraySetAsSeries(m_vwap_buf,    false);
      ArraySetAsSeries(m_diff_sq_buf, false);
     }

   if(ArraySize(out_rvscore) != rates_total)
     {
      ArrayResize(out_rvscore, rates_total);
      ArraySetAsSeries(out_rvscore, false);
      ArrayInitialize(out_rvscore, 0.0);
     }

// 2. Compute Continuous Underlying Rolling VWAP Stream
   m_rolling_vwap_calc.Calculate(rates_total, prev_calculated, time, open, high, low, close,
                                 tick_volume, volume, m_vwap_buf);

   int start = (prev_calculated > 0) ? (prev_calculated - 1) : 0;

// 3. Compute Squared Deviations
   for(int i = start; i < rates_total; i++)
     {
      double diff = close[i] - m_vwap_buf[i];
      m_diff_sq_buf[i] = diff * diff;
     }

// 4. Compute Normalized Sigma Z-Score
   for(int i = start; i < rates_total; i++)
     {
      double sum_sq = 0.0;
      int count = 0;

      // Sliding lookback across continuous series
      int lookback_limit = MathMin(i + 1, m_sigma_period);
      for(int j = 0; j < lookback_limit; j++)
        {
         sum_sq += m_diff_sq_buf[i - j];
         count++;
        }

      double std_dev = (count > 0) ? MathSqrt(sum_sq / (double)count) : 0.0;

      // Strict Floating-Point Epsilon Guard
      if(std_dev > 1.0e-9)
         out_rvscore[i] = (close[i] - m_vwap_buf[i]) / std_dev;
      else
         out_rvscore[i] = 0.0;
     }
  }

#endif // RVSCORE_CALCULATOR_MQH
//+------------------------------------------------------------------+
