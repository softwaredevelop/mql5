//+------------------------------------------------------------------+
//|                                             LScore_Calculator.mqh|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Optimized L-Score calculator with dynamic Laguerre baseline
#property description "Engine for Statistical Laguerre Z-Score (L-Score) calculation."

#ifndef LSCORE_CALCULATOR_MQH
#define LSCORE_CALCULATOR_MQH

#include <MyIncludes\Laguerre_Engine.mqh>

//+==================================================================+
//|             CLASS: CLScoreCalculator                             |
//+==================================================================+
class CLScoreCalculator
  {
protected:
   int               m_period;     // Volatility lookback period (N)
   double            m_gamma;      // Laguerre smoothing factor (0.0 to 1.0)
   CLaguerreEngine   *m_engine;     // Embedded Laguerre Engine

   double            m_filter[];   // Cached Laguerre Filter baseline

public:
                     CLScoreCalculator(void);
   virtual          ~CLScoreCalculator(void);

   bool              Init(double gamma, int period, bool is_ha);
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &out_lscore[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLScoreCalculator::CLScoreCalculator(void) : m_period(20), m_gamma(0.5), m_engine(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLScoreCalculator::~CLScoreCalculator(void)
  {
   if(CheckPointer(m_engine) != POINTER_INVALID)
      delete m_engine;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLScoreCalculator::Init(double gamma, int period, bool is_ha)
  {
   m_period = (period < 2) ? 2 : period;
   m_gamma = fmax(0.0, fmin(1.0, gamma));

   if(is_ha)
      m_engine = new CLaguerreEngine_HA();
   else
      m_engine = new CLaguerreEngine();

   if(CheckPointer(m_engine) == POINTER_INVALID || !m_engine.Init(m_gamma, SOURCE_PRICE))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Incremental & High Performance)                      |
//+------------------------------------------------------------------+
void CLScoreCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                  const double &open[], const double &high[], const double &low[], const double &close[],
                                  double &out_lscore[])
  {
   if(rates_total < m_period)
      return;

//--- 1. Resize Internal Filter Cache
   if(ArraySize(m_filter) != rates_total)
     {
      ArrayResize(m_filter, rates_total);
      ArraySetAsSeries(m_filter, false);
     }

//--- 2. Calculate Stateful Laguerre Filter Baseline (Updates m_filter and internal prepared prices)
   m_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, m_filter);

//--- 3. Calculate Volatility Distance in Sigma Units (L-Score)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : m_period - 1;
   if(start_index < m_period - 1)
      start_index = m_period - 1;

   for(int i = start_index; i < rates_total; i++)
     {
      double sum_sq = 0;
      double current_mean = m_filter[i];

      // Calculate standard deviation over the rolling window N relative to Laguerre Mean
      for(int k = 0; k < m_period; k++)
        {
         double diff = m_engine.GetPrice(i - k) - current_mean;
         sum_sq += diff * diff;
        }

      double std_dev = MathSqrt(sum_sq / m_period);

      if(std_dev > 1.0e-9) // Anti-division-by-zero safety guard
         out_lscore[i] = (m_engine.GetPrice(i) - current_mean) / std_dev;
      else
         out_lscore[i] = 0.0;
     }
  }

#endif // LSCORE_CALCULATOR_MQH
//+------------------------------------------------------------------+
