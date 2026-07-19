//+------------------------------------------------------------------+
//|       StochasticSlow_on_Laguerre_Adaptive_RSI_Calculator.mqh     |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Adaptive Stochastic on Adaptive Laguerre RSI engine
#property description "Stateful calculator implementing Stochastic Slow applied directly on Adaptive Laguerre RSI."

#ifndef STOCHASTIC_SLOW_ON_LAGUERRE_ADAPTIVE_RSI_CALCULATOR_MQH
#define STOCHASTIC_SLOW_ON_LAGUERRE_ADAPTIVE_RSI_CALCULATOR_MQH

#include <MyIncludes\Laguerre_Adaptive_RSI_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|    CLASS 1: CStochasticSlowOnLaguerreAdaptiveRSICalculator       |
//+==================================================================+
class CStochasticSlowOnLaguerreAdaptiveRSICalculator
  {
protected:
   int                             m_k_period;
   bool                            m_is_ha;

   //--- Composition
   CLaguerreAdaptiveRSICalculator *m_adaptive_rsi_calc; // Embedded Adaptive RSI Engine
   CMovingAverageCalculator       *m_slowing_engine;    // For Slow %K
   CMovingAverageCalculator       *m_signal_engine;     // For Signal %D

   //--- Internal Buffers
   double                          m_rsi_buffer[];      // Stores computed Adaptive Laguerre RSI
   double                          m_dummy_signal[];    // Required by the underlying RSI engine
   double                          m_raw_k[];           // Stores Fast %K

   //--- Helpers
   double                          Highest(const double &array[], int period, int current_pos);
   double                          Lowest(const double &array[], int period, int current_pos);

public:
                     CStochasticSlowOnLaguerreAdaptiveRSICalculator(void);
   virtual                        ~CStochasticSlowOnLaguerreAdaptiveRSICalculator(void);

   bool                            Init(ENUM_ADAPTIVE_METHOD method, int adaptive_period, double gamma_min, double gamma_max,
                                        int k_period, int slowing_period, ENUM_MA_TYPE slowing_method,
                                        int d_period, ENUM_MA_TYPE d_method, bool is_ha);

   //--- Standard Calculate (Without volume data)
   void                            Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
         const double &open[], const double &high[], const double &low[], const double &close[],
         double &slow_k_buffer[], double &signal_d_buffer[]);

   //--- Overloaded Calculate (With Volume for VWMA support)
   void                            Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
         const double &open[], const double &high[], const double &low[], const double &close[],
         const long &volume[],
         double &slow_k_buffer[], double &signal_d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStochasticSlowOnLaguerreAdaptiveRSICalculator::CStochasticSlowOnLaguerreAdaptiveRSICalculator(void)
   : m_adaptive_rsi_calc(NULL),
     m_slowing_engine(NULL),
     m_signal_engine(NULL),
     m_is_ha(false)
  {
   m_slowing_engine = new CMovingAverageCalculator();
   m_signal_engine  = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStochasticSlowOnLaguerreAdaptiveRSICalculator::~CStochasticSlowOnLaguerreAdaptiveRSICalculator(void)
  {
   if(CheckPointer(m_adaptive_rsi_calc) != POINTER_INVALID)
      delete m_adaptive_rsi_calc;
   if(CheckPointer(m_slowing_engine) != POINTER_INVALID)
      delete m_slowing_engine;
   if(CheckPointer(m_signal_engine) != POINTER_INVALID)
      delete m_signal_engine;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochasticSlowOnLaguerreAdaptiveRSICalculator::Init(ENUM_ADAPTIVE_METHOD method, int adaptive_period, double gamma_min, double gamma_max,
      int k_period, int slowing_period, ENUM_MA_TYPE slowing_method,
      int d_period, ENUM_MA_TYPE d_method, bool is_ha)
  {
   m_k_period = (k_period < 1) ? 1 : k_period;
   m_is_ha    = is_ha;

   if(CheckPointer(m_adaptive_rsi_calc) != POINTER_INVALID)
     {
      delete m_adaptive_rsi_calc;
      m_adaptive_rsi_calc = NULL;
     }

// Dynamic Polymorphic instantiation of the underlying Adaptive RSI Engine
   if(m_is_ha)
      m_adaptive_rsi_calc = new CLaguerreAdaptiveRSICalculator_HA();
   else
      m_adaptive_rsi_calc = new CLaguerreAdaptiveRSICalculator();

// Initialize Adaptive RSI with dummy MA settings internally (we will overwrite signal line on Stochastic level)
   if(CheckPointer(m_adaptive_rsi_calc) == POINTER_INVALID ||
      !m_adaptive_rsi_calc.Init(method, adaptive_period, gamma_min, gamma_max, 3, EMA, m_is_ha))
      return false;

   if(!m_slowing_engine.Init(slowing_period, slowing_method))
      return false;
   if(!m_signal_engine.Init(d_period, d_method))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard - No Volume)                                 |
//+------------------------------------------------------------------+
void CStochasticSlowOnLaguerreAdaptiveRSICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &slow_k_buffer[], double &signal_d_buffer[])
  {
   int required_bars = m_k_period + m_slowing_engine.GetPeriod() + m_signal_engine.GetPeriod() + 10;
   if(rates_total < required_bars)
      return;

//--- Resize state buffers and enforce chronological safety
   if(ArraySize(m_rsi_buffer) != rates_total)
     {
      ArrayResize(m_rsi_buffer,    rates_total);
      ArrayResize(m_dummy_signal,  rates_total);
      ArrayResize(m_raw_k,         rates_total);

      ArraySetAsSeries(m_rsi_buffer,    false);
      ArraySetAsSeries(m_dummy_signal,  false);
      ArraySetAsSeries(m_raw_k,         false);
     }

//--- 1. Calculate underlying Adaptive Laguerre RSI using composition
   m_adaptive_rsi_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_rsi_buffer, m_dummy_signal);

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int k_start = MathMax(m_k_period, start_index);

   if(k_start == m_k_period)
     {
      for(int i = 0; i < m_k_period; i++)
         m_raw_k[i] = 50.0;
     }

//--- 2. Calculate Stochastic Raw %K over Adaptive RSI values
   for(int i = k_start; i < rates_total; i++)
     {
      double highest_rsi = Highest(m_rsi_buffer, m_k_period, i);
      double lowest_rsi  = Lowest(m_rsi_buffer, m_k_period, i);
      double range = highest_rsi - lowest_rsi;

      if(range > 0.00001)
         m_raw_k[i] = (m_rsi_buffer[i] - lowest_rsi) / range * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i - 1] : 50.0;
     }

//--- 3. Calculate Slow %K (Slowing of Raw %K)
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, slow_k_buffer, m_k_period);

//--- 4. Calculate %D (Smoothing of Slow %K)
   int d_offset = m_k_period + m_slowing_engine.GetPeriod();
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, slow_k_buffer, signal_d_buffer, d_offset);
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Volume for VWMA support)            |
//+------------------------------------------------------------------+
void CStochasticSlowOnLaguerreAdaptiveRSICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      const long &volume[],
      double &slow_k_buffer[], double &signal_d_buffer[])
  {
   int required_bars = m_k_period + m_slowing_engine.GetPeriod() + m_signal_engine.GetPeriod() + 10;
   if(rates_total < required_bars)
      return;

//--- Convert volume locally for VWMA
   double d_vol[];
   ArrayResize(d_vol, rates_total);
   ArraySetAsSeries(d_vol, false);
   int start_sync = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   for(int i = start_sync; i < rates_total; i++)
      d_vol[i] = (double)volume[i];

//--- Run Standard calculation to obtain internal Raw %K on Adaptive RSI
   Calculate(rates_total, prev_calculated, price_type, open, high, low, close, slow_k_buffer, signal_d_buffer);

//--- Overwrite Slow %K & Signal %D with Volume-weighted averages
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, d_vol, slow_k_buffer, m_k_period);

   int d_offset = m_k_period + m_slowing_engine.GetPeriod();
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, slow_k_buffer, d_vol, signal_d_buffer, d_offset);
  }

//+------------------------------------------------------------------+
//| Highest Helper                                                   |
//+------------------------------------------------------------------+
double CStochasticSlowOnLaguerreAdaptiveRSICalculator::Highest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      if(current_pos - i < 0)
         break;
      if(res < array[current_pos - i])
         res = array[current_pos - i];
     }
   return res;
  }

//+------------------------------------------------------------------+
//| Lowest Helper                                                    |
//+------------------------------------------------------------------+
double CStochasticSlowOnLaguerreAdaptiveRSICalculator::Lowest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      if(current_pos - i < 0)
         break;
      if(res > array[current_pos - i])
         res = array[current_pos - i];
     }
   return res;
  }

//+==================================================================+
//|    CLASS 2: CStochasticSlowOnLaguerreAdaptiveRSICalculator_HA    |
//+==================================================================+
class CStochasticSlowOnLaguerreAdaptiveRSICalculator_HA : public CStochasticSlowOnLaguerreAdaptiveRSICalculator
  {
public:
                     CStochasticSlowOnLaguerreAdaptiveRSICalculator_HA(void)
     {
      m_is_ha = true;
     };
  };

#endif // STOCHASTIC_SLOW_ON_LAGUERRE_ADAPTIVE_RSI_CALCULATOR_MQH
//+------------------------------------------------------------------+
