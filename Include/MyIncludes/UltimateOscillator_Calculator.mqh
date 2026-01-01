//+------------------------------------------------------------------+
//|                                 UltimateOscillator_Calculator.mqh|
//|      VERSION 3.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|         CLASS 1: CUltimateOscillatorCalculator (Base Class)      |
//+==================================================================+
class CUltimateOscillatorCalculator
  {
protected:
   int               m_p1, m_p2, m_p3, m_signal_p;

   //--- Engine for Signal Line
   CMovingAverageCalculator m_signal_engine;

   //--- Persistent Buffers for Incremental Calculation
   double            m_src_high[], m_src_low[], m_src_close[];
   double            m_bp[], m_tr[];
   double            m_uo_buffer[];

   //--- Updated: Accepts start_index
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CUltimateOscillatorCalculator(void) {};
   virtual          ~CUltimateOscillatorCalculator(void) {};

   //--- Init now takes ENUM_MA_TYPE
   bool              Init(int p1, int p2, int p3, int signal_p, ENUM_MA_TYPE signal_ma);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &uo_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CUltimateOscillatorCalculator::Init(int p1, int p2, int p3, int signal_p, ENUM_MA_TYPE signal_ma)
  {
   m_p1             = (p1 < 1) ? 1 : p1;
   m_p2             = (p2 < 1) ? 1 : p2;
   m_p3             = (p3 < 1) ? 1 : p3;
   m_signal_p       = (signal_p < 1) ? 1 : signal_p;

// Initialize Signal Engine
   if(!m_signal_engine.Init(m_signal_p, signal_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CUltimateOscillatorCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
      double &uo_buffer[], double &signal_buffer[])
  {
   int max_period = MathMax(m_p1, MathMax(m_p2, m_p3));
   if(rates_total <= max_period)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_src_high) != rates_total)
     {
      ArrayResize(m_src_high, rates_total);
      ArrayResize(m_src_low, rates_total);
      ArrayResize(m_src_close, rates_total);
      ArrayResize(m_bp, rates_total);
      ArrayResize(m_tr, rates_total);
      ArrayResize(m_uo_buffer, rates_total);
     }

//--- 3. Prepare Source Data (Optimized)
   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

   const double W1=4.0, W2=2.0, W3=1.0, W_SUM=7.0;

//--- 4. Calculate BP and TR (Incremental)
   int loop_start_bp = MathMax(1, start_index);

   for(int i = loop_start_bp; i < rates_total; i++)
     {
      double true_low = MathMin(m_src_low[i], m_src_close[i-1]);
      m_bp[i] = m_src_close[i] - true_low;
      m_tr[i] = MathMax(m_src_high[i], m_src_close[i-1]) - true_low;
     }

//--- 5. Calculate UO (Incremental Sliding Window)
   int loop_start_uo = MathMax(max_period, start_index);

   for(int i = loop_start_uo; i < rates_total; i++)
     {
      // Optimization: Instead of persistent sums, we use a loop for robustness and simplicity.
      // For UO periods (typically 7, 14, 28), a loop is very fast.
      // Maintaining 6 persistent sum variables across ticks is error-prone.

      double sum_bp1=0, sum_tr1=0;
      double sum_bp2=0, sum_tr2=0;
      double sum_bp3=0, sum_tr3=0;

      // Calculate sums for period 1
      for(int j=0; j<m_p1; j++)
        {
         sum_bp1 += m_bp[i-j];
         sum_tr1 += m_tr[i-j];
        }

      // Calculate sums for period 2
      for(int j=0; j<m_p2; j++)
        {
         sum_bp2 += m_bp[i-j];
         sum_tr2 += m_tr[i-j];
        }

      // Calculate sums for period 3
      for(int j=0; j<m_p3; j++)
        {
         sum_bp3 += m_bp[i-j];
         sum_tr3 += m_tr[i-j];
        }

      double avg1 = (sum_tr1 > 0) ? sum_bp1 / sum_tr1 : 0;
      double avg2 = (sum_tr2 > 0) ? sum_bp2 / sum_tr2 : 0;
      double avg3 = (sum_tr3 > 0) ? sum_bp3 / sum_tr3 : 0;

      m_uo_buffer[i] = 100.0 * (W1*avg1 + W2*avg2 + W3*avg3) / W_SUM;
     }

//--- 6. Calculate Signal Line (Using Engine)
// UO is valid from index: max_period
   int uo_offset = max_period;
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, m_uo_buffer, signal_buffer, uo_offset);

//--- 7. Copy UO to Output
   ArrayCopy(uo_buffer, m_uo_buffer, 0, 0, rates_total);
  }

//+------------------------------------------------------------------+
//| Prepare Source Data (Standard - Optimized)                       |
//+------------------------------------------------------------------+
bool CUltimateOscillatorCalculator::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i] = high[i];
      m_src_low[i]  = low[i];
      m_src_close[i] = close[i];
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CUltimateOscillatorCalculator_HA            |
//+==================================================================+
class CUltimateOscillatorCalculator_HA : public CUltimateOscillatorCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[];

protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Source Data (Heikin Ashi - Optimized)                    |
//+------------------------------------------------------------------+
bool CUltimateOscillatorCalculator_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
      ArrayResize(m_ha_open, rates_total);

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_src_high, m_src_low, m_src_close);

   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
