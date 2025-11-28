//+------------------------------------------------------------------+
//|                           MACD_Laguerre_Histogram_Calculator.mqh |
//|      VERSION 1.20: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Laguerre_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Universal enum for smoothing types
enum ENUM_SMOOTHING_METHOD_LAGUERRE
  {
   SMOOTH_Laguerre,
   SMOOTH_SMA,
   SMOOTH_EMA,
   SMOOTH_SMMA,
   SMOOTH_LWMA
  };

//+==================================================================+
class CMACDLaguerreHistogramCalculator
  {
protected:
   double            m_fast_gamma, m_slow_gamma, m_signal_gamma;
   int               m_signal_period;
   ENUM_SMOOTHING_METHOD_LAGUERRE m_signal_ma_type;

   //--- Engines for MACD Line
   CLaguerreEngine   *m_fast_engine;
   CLaguerreEngine   *m_slow_engine;

   //--- Engines for Signal Line (Optimization)
   CLaguerreEngine   *m_signal_laguerre_engine;
   CMovingAverageCalculator *m_signal_ma_engine;

   virtual CLaguerreEngine *CreateEngineInstance(void);

public:
                     CMACDLaguerreHistogramCalculator(void);
   virtual          ~CMACDLaguerreHistogramCalculator(void);

   bool              Init(double g1, double g2, double sig_g, int sig_p, ENUM_SMOOTHING_METHOD_LAGUERRE sig_type);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &histogram[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CMACDLaguerreHistogramCalculator_HA : public CMACDLaguerreHistogramCalculator
  {
protected:
   virtual CLaguerreEngine *CreateEngineInstance(void) override;
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMACDLaguerreHistogramCalculator::CMACDLaguerreHistogramCalculator(void)
  {
   m_fast_engine = NULL;
   m_slow_engine = NULL;
   m_signal_laguerre_engine = NULL;
   m_signal_ma_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMACDLaguerreHistogramCalculator::~CMACDLaguerreHistogramCalculator(void)
  {
   if(CheckPointer(m_fast_engine) != POINTER_INVALID)
      delete m_fast_engine;
   if(CheckPointer(m_slow_engine) != POINTER_INVALID)
      delete m_slow_engine;
   if(CheckPointer(m_signal_laguerre_engine) != POINTER_INVALID)
      delete m_signal_laguerre_engine;
   if(CheckPointer(m_signal_ma_engine) != POINTER_INVALID)
      delete m_signal_ma_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
CLaguerreEngine *CMACDLaguerreHistogramCalculator::CreateEngineInstance(void) { return new CLaguerreEngine(); }
CLaguerreEngine *CMACDLaguerreHistogramCalculator_HA::CreateEngineInstance(void) { return new CLaguerreEngine_HA(); }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMACDLaguerreHistogramCalculator::Init(double g1, double g2, double sig_g, int sig_p, ENUM_SMOOTHING_METHOD_LAGUERRE sig_type)
  {
   m_fast_gamma = MathMin(g1, g2);
   m_slow_gamma = MathMax(g1, g2);
   m_signal_gamma = fmax(0.0, fmin(1.0, sig_g));
   m_signal_period = (sig_p < 1) ? 1 : sig_p;
   m_signal_ma_type = sig_type;

// Create Main Engines
   m_fast_engine = CreateEngineInstance();
   m_slow_engine = CreateEngineInstance();

   if(CheckPointer(m_fast_engine) == POINTER_INVALID || !m_fast_engine.Init(m_fast_gamma, SOURCE_PRICE) ||
      CheckPointer(m_slow_engine) == POINTER_INVALID || !m_slow_engine.Init(m_slow_gamma, SOURCE_PRICE))
      return false;

// Create Signal Engine based on type
   if(m_signal_ma_type == SMOOTH_Laguerre)
     {
      m_signal_laguerre_engine = new CLaguerreEngine();
      if(!m_signal_laguerre_engine.Init(m_signal_gamma, SOURCE_PRICE))
         return false;
     }
   else
     {
      m_signal_ma_engine = new CMovingAverageCalculator();
      ENUM_MA_TYPE ma_type = (ENUM_MA_TYPE)(m_signal_ma_type - 1);
      if(!m_signal_ma_engine.Init(m_signal_period, ma_type))
         return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CMACDLaguerreHistogramCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &histogram[])
  {
   if(rates_total < 2)
      return;

//--- 1. Calculate Fast and Slow Laguerre Filters (Incremental)
   double fast_filter[], slow_filter[];
// Note: The engine resizes them.

   m_fast_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, fast_filter);
   m_slow_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, slow_filter);

//--- 2. Calculate MACD Line
   double macd_line[];
   ArrayResize(macd_line, rates_total);

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start_index; i < rates_total; i++)
      macd_line[i] = fast_filter[i] - slow_filter[i];

//--- 3. Calculate Signal Line
   double signal_line[];
   ArrayResize(signal_line, rates_total);

   if(m_signal_ma_type == SMOOTH_Laguerre)
     {
      // Use Laguerre Engine on the MACD Line
      m_signal_laguerre_engine.CalculateFilter(rates_total, prev_calculated, PRICE_CLOSE,
            macd_line, macd_line, macd_line, macd_line,
            signal_line);
     }
   else
     {
      // Use MA Engine on the MACD Line
      m_signal_ma_engine.Calculate(rates_total, prev_calculated, PRICE_CLOSE,
                                   macd_line, macd_line, macd_line, macd_line,
                                   signal_line);
     }

//--- 4. Calculate Histogram
   for(int i = start_index; i < rates_total; i++)
      histogram[i] = macd_line[i] - signal_line[i];
  }
//+------------------------------------------------------------------+
