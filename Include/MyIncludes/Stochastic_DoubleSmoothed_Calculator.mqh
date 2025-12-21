//+------------------------------------------------------------------+
//|                           Stochastic_DoubleSmoothed_Calculator.mqh |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CStochasticDoubleSmoothedCalculator         |
//+==================================================================+
class CStochasticDoubleSmoothedCalculator
  {
protected:
   int               m_q, m_r, m_s, m_signal_p;

   //--- Engines for Smoothing
   CMovingAverageCalculator m_num_ema1_engine;
   CMovingAverageCalculator m_den_ema1_engine;
   CMovingAverageCalculator m_num_ema2_engine;
   CMovingAverageCalculator m_den_ema2_engine;
   CMovingAverageCalculator m_signal_engine;

   //--- Persistent Buffers
   double            m_high[], m_low[], m_close[];
   double            m_num_raw[], m_den_raw[];
   double            m_num_ema1[], m_den_ema1[];
   double            m_num_ema2[], m_den_ema2[];

   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CStochasticDoubleSmoothedCalculator(void) {};
   virtual          ~CStochasticDoubleSmoothedCalculator(void) {};

   //--- Init now takes MA types
   bool              Init(int q, int r, ENUM_MA_TYPE r_ma, int s, ENUM_MA_TYPE s_ma, int signal_p, ENUM_MA_TYPE signal_ma);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochasticDoubleSmoothedCalculator::Init(int q, int r, ENUM_MA_TYPE r_ma, int s, ENUM_MA_TYPE s_ma, int signal_p, ENUM_MA_TYPE signal_ma)
  {
   m_q = (q < 1) ? 1 : q;
   m_r = (r < 1) ? 1 : r;
   m_s = (s < 1) ? 1 : s;
   m_signal_p = (signal_p < 1) ? 1 : signal_p;

// Initialize Engines
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
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CStochasticDoubleSmoothedCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
// Minimum bars check
   if(rates_total <= m_q + m_r + m_s + m_signal_p)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_high) != rates_total)
     {
      ArrayResize(m_high, rates_total);
      ArrayResize(m_low, rates_total);
      ArrayResize(m_close, rates_total);

      ArrayResize(m_num_raw, rates_total);
      ArrayResize(m_den_raw, rates_total);

      ArrayResize(m_num_ema1, rates_total);
      ArrayResize(m_den_ema1, rates_total);

      ArrayResize(m_num_ema2, rates_total);
      ArrayResize(m_den_ema2, rates_total);
     }

   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

//--- 1. Calculate Raw Numerator and Denominator
   int loop_start_raw = MathMax(m_q - 1, start_index);

   for(int i = loop_start_raw; i < rates_total; i++)
     {
      double highest = m_high[i];
      double lowest = m_low[i];

      for(int j = 1; j < m_q; j++)
        {
         highest = MathMax(highest, m_high[i-j]);
         lowest = MathMin(lowest, m_low[i-j]);
        }

      m_num_raw[i] = m_close[i] - lowest;
      m_den_raw[i] = highest - lowest;
     }

//--- 2. First Smoothing (EMA1)
// Offset: m_q - 1
   int offset1 = m_q - 1;
   m_num_ema1_engine.CalculateOnArray(rates_total, prev_calculated, m_num_raw, m_num_ema1, offset1);
   m_den_ema1_engine.CalculateOnArray(rates_total, prev_calculated, m_den_raw, m_den_ema1, offset1);

//--- 3. Second Smoothing (EMA2)
// Offset: offset1 + m_r - 1
   int offset2 = offset1 + m_r - 1;
   m_num_ema2_engine.CalculateOnArray(rates_total, prev_calculated, m_num_ema1, m_num_ema2, offset2);
   m_den_ema2_engine.CalculateOnArray(rates_total, prev_calculated, m_den_ema1, m_den_ema2, offset2);

//--- 4. Calculate %K
// Valid from: offset2 + m_s - 1
   int k_start = offset2 + m_s - 1;
   int loop_start_k = MathMax(k_start, start_index);

   if(prev_calculated == 0)
      ArrayInitialize(k_buffer, EMPTY_VALUE);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      if(m_den_ema2[i] > 0.000001)
         k_buffer[i] = 100.0 * m_num_ema2[i] / m_den_ema2[i];
      else
         k_buffer[i] = (i > 0) ? k_buffer[i-1] : 50.0;
     }

//--- 5. Calculate %D (Signal Line)
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, k_start);
  }

//+------------------------------------------------------------------+
//| Prepare Source Data (Standard - Optimized)                       |
//+------------------------------------------------------------------+
bool CStochasticDoubleSmoothedCalculator::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      m_high[i] = high[i];
      m_low[i] = low[i];
      m_close[i] = close[i];
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CStochasticDoubleSmoothedCalculator_HA      |
//+==================================================================+
class CStochasticDoubleSmoothedCalculator_HA : public CStochasticDoubleSmoothedCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];
protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CStochasticDoubleSmoothedCalculator_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_ha_high, m_ha_low, m_ha_close);
   for(int i = start_index; i < rates_total; i++)
     {
      m_high[i] = m_ha_high[i];
      m_low[i] = m_ha_low[i];
      m_close[i] = m_ha_close[i];
     }
   return true;
  }
//+------------------------------------------------------------------+
