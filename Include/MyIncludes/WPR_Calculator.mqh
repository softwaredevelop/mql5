//+------------------------------------------------------------------+
//|                                            WPR_Calculator.mqh    |
//|      VERSION 3.00: Uses Stochastic & MA Engines.                 |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\StochasticFast_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|           CLASS: CWPRCalculator                                  |
//+==================================================================+
class CWPRCalculator
  {
protected:
   int               m_wpr_period;

   //--- Composition: Use StochFast for core logic + MA Engine for Signal
   CStochasticFastCalculator *m_stoch_calc;
   CMovingAverageCalculator   m_signal_engine;

   //--- Intermediate Buffer for %K (0..100 range)
   double            m_k_buffer[];
   //--- Dummy buffer for StochFast %D (we don't use it, but API requires it)
   double            m_dummy_d[];

public:
                     CWPRCalculator(void);
   virtual          ~CWPRCalculator(void);

   //--- Init now takes ENUM_MA_TYPE for Signal
   bool              Init(int wpr_p, int signal_p, ENUM_MA_TYPE signal_ma, bool use_ha);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &wpr_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CWPRCalculator::CWPRCalculator(void) : m_stoch_calc(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CWPRCalculator::~CWPRCalculator(void)
  {
   if(CheckPointer(m_stoch_calc) != POINTER_INVALID)
      delete m_stoch_calc;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CWPRCalculator::Init(int wpr_p, int signal_p, ENUM_MA_TYPE signal_ma, bool use_ha)
  {
   m_wpr_period = (wpr_p < 1) ? 1 : wpr_p;

// Instantiate correct Stoch calculator
   if(use_ha)
      m_stoch_calc = new CStochasticFastCalculator_HA();
   else
      m_stoch_calc = new CStochasticFastCalculator();

// Init StochFast. We only care about %K (period = wpr_p).
// %D params for StochFast are dummy (1, SMA) as we ignore its %D output.
   if(!m_stoch_calc.Init(m_wpr_period, 1, SMA))
      return false;

// Init Signal Engine
   return m_signal_engine.Init(signal_p, signal_ma);
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CWPRCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &wpr_buffer[], double &signal_buffer[])
  {
   if(rates_total <= m_wpr_period + m_signal_engine.GetPeriod())
      return;
   if(CheckPointer(m_stoch_calc) == POINTER_INVALID)
      return;

// Resize internal buffers
   if(ArraySize(m_k_buffer) != rates_total)
     {
      ArrayResize(m_k_buffer, rates_total);
      ArrayResize(m_dummy_d, rates_total);
     }

//--- 1. Calculate %K using StochFast Engine
// This gives us values in 0..100 range
// Note: StochFast handles incremental logic internally
   m_stoch_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_k_buffer, m_dummy_d);

//--- 2. Convert %K to WPR (%R = %K - 100)
// WPR range is -100..0
   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;
   int loop_start = MathMax(m_wpr_period - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      wpr_buffer[i] = m_k_buffer[i] - 100.0;
     }

//--- 3. Calculate Signal Line using MA Engine
// Offset: m_wpr_period - 1 (same as Stoch %K)
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, wpr_buffer, signal_buffer, m_wpr_period - 1);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
