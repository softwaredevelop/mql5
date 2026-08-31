//+------------------------------------------------------------------+
//|                                             LScore_Calculator.mqh|
//|      Engine for Statistical Laguerre Z-Score (L-Score)           |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Overloaded initialization, leak-free pointer management & bounds protection

#ifndef LSCORE_CALCULATOR_MQH
#define LSCORE_CALCULATOR_MQH

#include <MyIncludes\Laguerre_Engine.mqh>

//+==================================================================+
//|             CLASS: CLScoreCalculator                             |
//+==================================================================+
class CLScoreCalculator
  {
protected:
   int                       m_period;
   double                    m_gamma;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;
   CLaguerreEngine          *m_engine;

   //--- Persistent State Buffers
   double                    m_filter[];
   double                    m_price_cache[];

public:
                     CLScoreCalculator(void);
   virtual                  ~CLScoreCalculator(void);

   //--- Legacy Compatible Init (3 Parameters)
   bool                      Init(const double gamma, const int period, const bool is_ha)
     {
      ENUM_APPLIED_PRICE_HA_ALL src = is_ha ? PRICE_HA_CLOSE : PRICE_CLOSE_STD;
      return Init(gamma, period, src);
     }

   //--- Enhanced Pro Init (3 Parameters with Full Price Enum)
   bool                      Init(const double gamma, const int period, const ENUM_APPLIED_PRICE_HA_ALL price_source);

   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &out_lscore[]);

   //--- Legacy Overload with price_type parameter
   void                      Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &out_lscore[])
     {
      Calculate(rates_total, prev_calculated, open, high, low, close, out_lscore);
     }

   int                       GetRequiredWarmup(void) const { return m_period; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLScoreCalculator::CLScoreCalculator(void) : m_period(20),
   m_gamma(0.5),
   m_source_price(PRICE_CLOSE_STD),
   m_engine(NULL)
  {
   ArraySetAsSeries(m_filter,      false);
   ArraySetAsSeries(m_price_cache, false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLScoreCalculator::~CLScoreCalculator(void)
  {
   if(CheckPointer(m_engine) != POINTER_INVALID)
     {
      delete m_engine;
      m_engine = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Enhanced Pro Initialization                                      |
//+------------------------------------------------------------------+
bool CLScoreCalculator::Init(const double gamma, const int period, const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_period       = (period < 2) ? 2 : period;
   m_gamma        = fmax(0.0, fmin(1.0, gamma));
   m_source_price = price_source;

   if(CheckPointer(m_engine) != POINTER_INVALID)
     {
      delete m_engine;
      m_engine = NULL;
     }

   if(m_source_price <= PRICE_HA_CLOSE)
      m_engine = new CLaguerreEngine_HA();
   else
      m_engine = new CLaguerreEngine();

   if(CheckPointer(m_engine) == POINTER_INVALID)
      return false;

   return m_engine.Init(m_gamma, SOURCE_PRICE, m_source_price);
  }

//+------------------------------------------------------------------+
//| Main Incremental Calculation Loop                                |
//+------------------------------------------------------------------+
void CLScoreCalculator::Calculate(const int rates_total, const int prev_calculated,
                                  const double &open[], const double &high[],
                                  const double &low[], const double &close[],
                                  double &out_lscore[])
  {
   if(rates_total < m_period || CheckPointer(m_engine) == POINTER_INVALID)
      return;

// Safe allocation of destination array
   if(ArraySize(out_lscore) != rates_total)
     {
      ArrayResize(out_lscore, rates_total);
      ArraySetAsSeries(out_lscore, false);
     }

// Safe allocation of internal filter buffer
   if(ArraySize(m_filter) != rates_total)
     {
      ArrayResize(m_filter, rates_total);
      ArraySetAsSeries(m_filter, false);
     }

// 1. Calculate Laguerre Baseline Filter
   m_engine.CalculateFilter(rates_total, prev_calculated, open, high, low, close, m_filter);

// 2. Clean invalid initial range strictly on fresh calculation
   if(prev_calculated == 0)
     {
      for(int i = 0; i < m_period; i++)
         out_lscore[i] = 0.0;
     }

   int start = (prev_calculated > m_period) ? (prev_calculated - 1) : (m_period - 1);
   if(start < m_period - 1)
      start = m_period - 1;

// 3. Compute Rolling Z-Score of difference from Laguerre Mean
   for(int i = start; i < rates_total; i++)
     {
      double current_mean = m_filter[i];
      double current_price = m_engine.GetPrice(i);

      if(current_mean == 0.0 || current_mean == EMPTY_VALUE)
        {
         out_lscore[i] = 0.0;
         continue;
        }

      double sum_sq = 0.0;
      for(int k = 0; k < m_period; k++)
        {
         double p_k = m_engine.GetPrice(i - k);
         double diff = p_k - current_mean;
         sum_sq += diff * diff;
        }

      double std_dev = MathSqrt(sum_sq / (double)m_period);

      if(std_dev > 1.0e-9)
         out_lscore[i] = (current_price - current_mean) / std_dev;
      else
         out_lscore[i] = 0.0;
     }
  }

#endif // LSCORE_CALCULATOR_MQH
//+------------------------------------------------------------------+
