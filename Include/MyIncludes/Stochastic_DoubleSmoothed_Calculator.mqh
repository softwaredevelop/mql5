//+------------------------------------------------------------------+
//|                           Stochastic_DoubleSmoothed_Calculator.mqh |
//|      VERSION 2.10: In-Place Heikin Ashi Math & State Safety       |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.10" // Enterprise Refactor: In-Place HA Mapping & Chronological Array Bounds
#property description "High-performance calculation engine for William Blau's Double Smoothed Stochastic."

#ifndef STOCHASTIC_DOUBLE_SMOOTHED_CALCULATOR_MQH
#define STOCHASTIC_DOUBLE_SMOOTHED_CALCULATOR_MQH

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CStochasticDoubleSmoothedCalculator         |
//+==================================================================+
class CStochasticDoubleSmoothedCalculator
  {
protected:
   int                      m_q, m_r, m_s, m_signal_p;

   //--- Engines for Double Smoothing Cascade (Zero Heap Overhead!)
   CMovingAverageCalculator m_num_ema1_engine;
   CMovingAverageCalculator m_den_ema1_engine;
   CMovingAverageCalculator m_num_ema2_engine;
   CMovingAverageCalculator m_den_ema2_engine;
   CMovingAverageCalculator m_signal_engine;

   //--- Persistent State Buffers
   double                   m_high[], m_low[], m_close[];
   double                   m_num_raw[], m_den_raw[];
   double                   m_num_ema1[], m_den_ema1[];
   double                   m_num_ema2[], m_den_ema2[];

   virtual bool             PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CStochasticDoubleSmoothedCalculator(void) : m_q(5), m_r(3), m_s(3), m_signal_p(3) {};
   virtual                 ~CStochasticDoubleSmoothedCalculator(void) {};

   bool                     Init(int q, int r, ENUM_MA_TYPE r_ma, int s, ENUM_MA_TYPE s_ma, int signal_p, ENUM_MA_TYPE signal_ma);

   void                     Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                                      double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochasticDoubleSmoothedCalculator::Init(int q, int r, ENUM_MA_TYPE r_ma, int s, ENUM_MA_TYPE s_ma, int signal_p, ENUM_MA_TYPE signal_ma)
  {
   m_q        = (q < 1) ? 1 : q;
   m_r        = (r < 1) ? 1 : r;
   m_s        = (s < 1) ? 1 : s;
   m_signal_p = (signal_p < 1) ? 1 : signal_p;

// Initialize all 5 smoothing engines
   if(!m_num_ema1_engine.Init(m_r, r_ma))
      return false;
   if(!m_den_ema1_engine.Init(m_r, r_ma))
      return false;
   if(!m_num_ema2_engine.Init(m_s, s_ma))
      return false;
   if(!m_den_ema2_engine.Init(m_s, s_ma))
      return false;
   if(!m_signal_engine.Init(m_signal_p, signal_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Incremental O(1))                              |
//+------------------------------------------------------------------+
void CStochasticDoubleSmoothedCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
   int warmup = m_q + m_r + m_s + m_signal_p;
   if(rates_total <= warmup)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize internal state buffers & enforce chronological safety
   if(ArraySize(m_high) != rates_total)
     {
      ArrayResize(m_high,     rates_total);
      ArraySetAsSeries(m_high,     false);
      ArrayResize(m_low,      rates_total);
      ArraySetAsSeries(m_low,      false);
      ArrayResize(m_close,    rates_total);
      ArraySetAsSeries(m_close,    false);
      ArrayResize(m_num_raw,  rates_total);
      ArraySetAsSeries(m_num_raw,  false);
      ArrayResize(m_den_raw,  rates_total);
      ArraySetAsSeries(m_den_raw,  false);
      ArrayResize(m_num_ema1, rates_total);
      ArraySetAsSeries(m_num_ema1, false);
      ArrayResize(m_den_ema1, rates_total);
      ArraySetAsSeries(m_den_ema1, false);
      ArrayResize(m_num_ema2, rates_total);
      ArraySetAsSeries(m_num_ema2, false);
      ArrayResize(m_den_ema2, rates_total);
      ArraySetAsSeries(m_den_ema2, false);
     }

// Safe allocation of output buffers
   if(ArraySize(k_buffer) != rates_total)
     {
      ArrayResize(k_buffer, rates_total);
      ArraySetAsSeries(k_buffer, false);
      ArrayInitialize(k_buffer, EMPTY_VALUE);
     }
   if(ArraySize(d_buffer) != rates_total)
     {
      ArrayResize(d_buffer, rates_total);
      ArraySetAsSeries(d_buffer, false);
      ArrayInitialize(d_buffer, EMPTY_VALUE);
     }

   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

// 1. Calculate Raw Numerator and Denominator
   int loop_start_raw = MathMax(m_q - 1, start_index);

   for(int i = loop_start_raw; i < rates_total; i++)
     {
      double highest = m_high[i];
      double lowest  = m_low[i];

      for(int j = 1; j < m_q; j++)
        {
         highest = MathMax(highest, m_high[i - j]);
         lowest  = MathMin(lowest,  m_low[i - j]);
        }

      m_num_raw[i] = m_close[i] - lowest;
      m_den_raw[i] = highest - lowest;
     }

// 2. First Smoothing Stage (EMA1)
   int offset1 = m_q - 1;
   m_num_ema1_engine.CalculateOnArray(rates_total, prev_calculated, m_num_raw, m_num_ema1, offset1);
   m_den_ema1_engine.CalculateOnArray(rates_total, prev_calculated, m_den_raw, m_den_ema1, offset1);

// 3. Second Smoothing Stage (EMA2)
   int offset2 = offset1 + m_r - 1;
   m_num_ema2_engine.CalculateOnArray(rates_total, prev_calculated, m_num_ema1, m_num_ema2, offset2);
   m_den_ema2_engine.CalculateOnArray(rates_total, prev_calculated, m_den_ema1, m_den_ema2, offset2);

// 4. Calculate %K Ratio (Post-Smoothing Division)
   int k_start = offset2 + m_s - 1;
   int loop_start_k = MathMax(k_start, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      if(m_den_ema2[i] > 1.0e-9)
         k_buffer[i] = 100.0 * (m_num_ema2[i] / m_den_ema2[i]);
      else
         k_buffer[i] = (i > 0) ? k_buffer[i - 1] : 50.0;
     }

// 5. Calculate %D Signal Line (Smoothing of %K)
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, k_start);
  }

//+------------------------------------------------------------------+
//| Prepare Source Data (Standard)                                   |
//+------------------------------------------------------------------+
bool CStochasticDoubleSmoothedCalculator::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      m_high[i]  = high[i];
      m_low[i]   = low[i];
      m_close[i] = close[i];
     }
   return true;
  }

//+==================================================================+
//|         CLASS 2: CStochasticDoubleSmoothedCalculator_HA          |
//+==================================================================+
class CStochasticDoubleSmoothedCalculator_HA : public CStochasticDoubleSmoothedCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double                 m_ha_open[];

protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Source Data (Direct In-Place Heikin Ashi Calculation)    |
//+------------------------------------------------------------------+
bool CStochasticDoubleSmoothedCalculator_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArraySetAsSeries(m_ha_open, false);
     }

// DIRECT IN-PLACE CALCULATION: Eliminates 3 temp arrays and 1 copy loop!
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_high, m_low, m_close);

   return true;
  }

#endif // STOCHASTIC_DOUBLE_SMOOTHED_CALCULATOR_MQH
//+------------------------------------------------------------------+
