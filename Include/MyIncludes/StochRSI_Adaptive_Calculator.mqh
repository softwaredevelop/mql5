//+------------------------------------------------------------------+
//|                                StochRSI_Adaptive_Calculator.mqh  |
//|      Engine for Stochastic applied to Adaptive RSI.              |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\RSI_Adaptive_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|             CLASS 1: CStochRSIAdaptiveCalculator                 |
//+==================================================================+
class CStochRSIAdaptiveCalculator
  {
protected:
   //--- Adaptive RSI Params
   int               m_pivotal_period, m_vola_short, m_vola_long;
   ENUM_ADAPTIVE_SOURCE_RSI m_adaptive_source;

   //--- Stochastic Params
   int               m_k_period;

   //--- Engines
   CAdaptiveRSICalculator *m_rsi_calculator;
   CMovingAverageCalculator m_slowing_engine;
   CMovingAverageCalculator m_signal_engine;

   //--- Persistent Buffers
   double            m_rsi_buffer[];
   double            m_raw_k[];

   double            Highest(const double &array[], int period, int current_pos);
   double            Lowest(const double &array[], int period, int current_pos);

   //--- Factory Method
   virtual void      CreateRSIEngine(void);

public:
                     CStochRSIAdaptiveCalculator(void);
   virtual          ~CStochRSIAdaptiveCalculator(void);

   bool              Init(int pivotal_p, int vola_s, int vola_l, ENUM_ADAPTIVE_SOURCE_RSI adapt_src,
                          int k_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStochRSIAdaptiveCalculator::CStochRSIAdaptiveCalculator(void)
  {
   m_rsi_calculator = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStochRSIAdaptiveCalculator::~CStochRSIAdaptiveCalculator(void)
  {
   if(CheckPointer(m_rsi_calculator) != POINTER_INVALID)
      delete m_rsi_calculator;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CStochRSIAdaptiveCalculator::CreateRSIEngine(void)
  {
   m_rsi_calculator = new CAdaptiveRSICalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochRSIAdaptiveCalculator::Init(int pivotal_p, int vola_s, int vola_l, ENUM_ADAPTIVE_SOURCE_RSI adapt_src,
                                       int k_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma)
  {
   m_pivotal_period = pivotal_p;
   m_vola_short     = vola_s;
   m_vola_long      = vola_l;
   m_adaptive_source= adapt_src;
   m_k_period       = k_p;

   CreateRSIEngine();
   if(CheckPointer(m_rsi_calculator) == POINTER_INVALID)
      return false;
   if(!m_rsi_calculator.Init(m_pivotal_period, m_vola_short, m_vola_long, m_adaptive_source))
      return false;

   if(!m_slowing_engine.Init(slow_p, slow_ma))
      return false;
   if(!m_signal_engine.Init(d_p, d_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CStochRSIAdaptiveCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
// Minimum bars check (approximate)
   int min_bars = m_vola_long + m_pivotal_period + m_k_period + m_slowing_engine.GetPeriod() + m_signal_engine.GetPeriod();
   if(rates_total <= min_bars)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_rsi_buffer) != rates_total)
     {
      ArrayResize(m_rsi_buffer, rates_total);
      ArrayResize(m_raw_k, rates_total);
     }

//--- 1. Calculate Adaptive RSI (Delegated)
// Note: The RSI calculator handles its own price preparation and incremental logic
   m_rsi_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_rsi_buffer);

//--- 2. Calculate Raw %K on Adaptive RSI
// RSI valid from: m_vola_long + m_pivotal_period (approx)
// Raw %K valid from: RSI_Start + m_k_period - 1
// We use a safe start index based on the RSI calculator's logic
   int rsi_start = m_vola_long + m_pivotal_period;
   int raw_k_start = rsi_start + m_k_period - 1;
   int loop_start_k = MathMax(raw_k_start, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      double highest_rsi = Highest(m_rsi_buffer, m_k_period, i);
      double lowest_rsi  = Lowest(m_rsi_buffer, m_k_period, i);
      double range = highest_rsi - lowest_rsi;

      if(range > 0.00001)
         m_raw_k[i] = (m_rsi_buffer[i] - lowest_rsi) / range * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i-1] : 50.0;
     }

//--- 3. Calculate Slow %K (Main Line)
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, k_buffer, raw_k_start);

//--- 4. Calculate %D (Signal Line)
   int d_offset = raw_k_start + m_slowing_engine.GetPeriod() - 1;
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, d_offset);
  }

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
double CStochRSIAdaptiveCalculator::Highest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res < array[index])
         res = array[index];
     }
   return(res);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CStochRSIAdaptiveCalculator::Lowest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res > array[index])
         res = array[index];
     }
   return(res);
  }

//+==================================================================+
//|             CLASS 2: CStochRSIAdaptiveCalculator_HA              |
//+==================================================================+
class CStochRSIAdaptiveCalculator_HA : public CStochRSIAdaptiveCalculator
  {
protected:
   virtual void      CreateRSIEngine(void) override;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStochRSIAdaptiveCalculator_HA::CreateRSIEngine(void)
  {
   m_rsi_calculator = new CAdaptiveRSICalculator_HA();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
