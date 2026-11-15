//+------------------------------------------------------------------+
//|                                     StochasticFast_Calculator.mqh|
//|      DSP Engine for Fast Stochastic Oscillator                   |
//|      VERSION 3.00: Direct In-Place HA Math & Capacity Memory     |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.00" // Enterprise Edition: Direct In-Place HA & Zero Heap Allocation
#property description "High-performance calculation engine for Fast Stochastic Oscillator."

#ifndef STOCHASTIC_FAST_CALCULATOR_MQH
#define STOCHASTIC_FAST_CALCULATOR_MQH

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|           CLASS: CStochasticFastCalculator                       |
//+==================================================================+
class CStochasticFastCalculator
  {
protected:
   int                      m_k_period;

   //--- Composition: Embedded MA Engine for %D smoothing
   CMovingAverageCalculator m_ma_engine;

   //--- Persistent State Buffers
   double                   m_src_high[];
   double                   m_src_low[];
   double                   m_src_close[];

   double                   Highest(const int period, const int current_pos) const;
   double                   Lowest(const int period, const int current_pos) const;

   virtual bool             PrepareSourceData(const int rates_total, const int start_index,
         const double &open[], const double &high[],
         const double &low[], const double &close[]);

public:
                     CStochasticFastCalculator(void);
   virtual                 ~CStochasticFastCalculator(void) {}

   //--- 100% Backward Compatible Init (Extended ENUM_MA_TYPE Support)
   bool                     Init(const int k_p, const int d_p, const ENUM_MA_TYPE d_ma);

   void                     Calculate(const int rates_total, const int prev_calculated,
                                      const double &open[], const double &high[],
                                      const double &low[], const double &close[],
                                      double &k_buffer[], double &d_buffer[]);

   int                      GetKPeriod(void)    const { return m_k_period; }
   int                      GetDPeriod(void)    const { return m_ma_engine.GetPeriod(); }
   ENUM_MA_TYPE             GetDMAType(void)    const { return m_ma_engine.GetMAType(); }
   int                      GetWarmupBars(void) const { return m_k_period + m_ma_engine.GetPeriod() - 2; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStochasticFastCalculator::CStochasticFastCalculator(void) : m_k_period(14)
  {
   ArraySetAsSeries(m_src_high,  false);
   ArraySetAsSeries(m_src_low,   false);
   ArraySetAsSeries(m_src_close, false);
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochasticFastCalculator::Init(const int k_p, const int d_p, const ENUM_MA_TYPE d_ma)
  {
   m_k_period = (k_p < 1) ? 1 : k_p;
   return m_ma_engine.Init(d_p, d_ma);
  }

//+------------------------------------------------------------------+
//| Main Calculation (Incremental O(1))                              |
//+------------------------------------------------------------------+
void CStochasticFastCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
   int min_bars = m_k_period + m_ma_engine.GetPeriod();
   if(rates_total <= min_bars)
      return;

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

// Resize working buffers with memory reservation capacity
   if(ArraySize(m_src_high) != rates_total)
     {
      ArrayResize(m_src_high,  rates_total, 2048);
      ArrayResize(m_src_low,   rates_total, 2048);
      ArrayResize(m_src_close, rates_total, 2048);

      ArraySetAsSeries(m_src_high,  false);
      ArraySetAsSeries(m_src_low,   false);
      ArraySetAsSeries(m_src_close, false);
     }

// Prepare source prices (Standard vs. In-Place Heikin Ashi)
   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

// 1. Calculate Fast %K Line
   int loop_start_k = MathMax(m_k_period - 1, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      double highest_h = Highest(m_k_period, i);
      double lowest_l  = Lowest(m_k_period, i);
      double range     = highest_h - lowest_l;

      // Numerical Epsilon Guard
      if(range > 1.0e-9)
         k_buffer[i] = ((m_src_close[i] - lowest_l) / range) * 100.0;
      else
         k_buffer[i] = (i > 0) ? k_buffer[i - 1] : 50.0;
     }

// Pre-warmup zone filling
   if(prev_calculated == 0)
     {
      for(int i = 0; i < loop_start_k; i++)
         k_buffer[i] = EMPTY_VALUE;
     }

// 2. Calculate %D Signal Line using Modular MA Engine
// Data in k_buffer is valid starting from index (m_k_period - 1)
   m_ma_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, m_k_period - 1);
  }

//+------------------------------------------------------------------+
//| Prepare Source Data (Standard OHLC)                              |
//+------------------------------------------------------------------+
bool CStochasticFastCalculator::PrepareSourceData(const int rates_total, const int start_index,
      const double &open[], const double &high[],
      const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i]  = high[i];
      m_src_low[i]   = low[i];
      m_src_close[i] = close[i];
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Helper: Scanning Highest High                                    |
//+------------------------------------------------------------------+
double CStochasticFastCalculator::Highest(const int period, const int current_pos) const
  {
   double res = m_src_high[current_pos];
   int limit = MathMax(0, current_pos - period + 1);

   for(int i = current_pos - 1; i >= limit; i--)
     {
      if(m_src_high[i] > res)
         res = m_src_high[i];
     }
   return res;
  }

//+------------------------------------------------------------------+
//| Helper: Scanning Lowest Low                                      |
//+------------------------------------------------------------------+
double CStochasticFastCalculator::Lowest(const int period, const int current_pos) const
  {
   double res = m_src_low[current_pos];
   int limit = MathMax(0, current_pos - period + 1);

   for(int i = current_pos - 1; i >= limit; i--)
     {
      if(m_src_low[i] < res)
         res = m_src_low[i];
     }
   return res;
  }

//+==================================================================+
//| CLASS 2: CStochasticFastCalculator_HA (Heikin Ashi Subclass)     |
//+==================================================================+
class CStochasticFastCalculator_HA : public CStochasticFastCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double                 m_ha_open[]; // Only HA open requires persistent recursive state

protected:
   virtual bool           PrepareSourceData(const int rates_total, const int start_index,
         const double &open[], const double &high[],
         const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Source Data (Direct In-Place Heikin Ashi Calculation)    |
//| Eliminates 3 temp arrays and 1 unnecessary copy loop!            |
//+------------------------------------------------------------------+
bool CStochasticFastCalculator_HA::PrepareSourceData(const int rates_total, const int start_index,
      const double &open[], const double &high[],
      const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total, 2048);
      ArraySetAsSeries(m_ha_open, false);
     }

// DIRECT IN-PLACE COMPUTATION: Output straight into destination registers!
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_src_high, m_src_low, m_src_close);

   return true;
  }

#endif // STOCHASTIC_FAST_CALCULATOR_MQH
//+------------------------------------------------------------------+
