//+------------------------------------------------------------------+
//|                                          VScore_Calculator.mqh   |
//|      Engine for V-Score (VWAP Z-Score).                          |
//|      Measures statistical deviation from VWAP.                   |
//|      VERSION 2.00: Strictly O(1) Incremental Optimized.          |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\VWAP_Calculator.mqh>

//+------------------------------------------------------------------+
//| Class CVScoreCalculator                                          |
//+------------------------------------------------------------------+
class CVScoreCalculator
  {
protected:
   int               m_period;
   CVWAPCalculator   *m_vwap_calc;

   // Persistent Buffers for Incremental Calculation
   double            m_vwap_buf[];
   double            m_vwap_odd[];
   double            m_vwap_even[];

public:
                     CVScoreCalculator();
   virtual          ~CVScoreCalculator();

   bool              Init(int period, ENUM_VWAP_PERIOD vwap_reset);

   void              Calculate(int rates_total, int prev_calculated,
                               const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &tick_volume[], const long &volume[],
                               double &out_vscore[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVScoreCalculator::CVScoreCalculator() : m_vwap_calc(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CVScoreCalculator::~CVScoreCalculator()
  {
   if(CheckPointer(m_vwap_calc) == POINTER_DYNAMIC)
      delete m_vwap_calc;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CVScoreCalculator::Init(int period, ENUM_VWAP_PERIOD vwap_reset)
  {
   m_period = (period < 2) ? 2 : period;

   m_vwap_calc = new CVWAPCalculator();
// Init VWAP with Tick Volume, enabled
   if(!m_vwap_calc.Init(vwap_reset, VOLUME_TICK, 0, true))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Strictly O(1) Optimized)                       |
//+------------------------------------------------------------------+
void CVScoreCalculator::Calculate(int rates_total, int prev_calculated,
                                  const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[],
                                  const long &tick_volume[], const long &volume[],
                                  double &out_vscore[])
  {
   if(rates_total < m_period)
      return;

// 1. Manage Internal Buffers
   if(ArraySize(m_vwap_buf) != rates_total)
     {
      ArrayResize(m_vwap_buf, rates_total);
      ArrayResize(m_vwap_odd, rates_total);
      ArrayResize(m_vwap_even, rates_total);
     }

// 2. Calculate VWAP Incrementally! (Passing prev_calculated)
   m_vwap_calc.Calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, m_vwap_odd, m_vwap_even);

// 3. Calculate Standard Deviation of (Price - VWAP)
// Determine start index for true O(1) performance
   int start = (prev_calculated > m_period) ? prev_calculated - 1 : m_period;

   for(int i = start; i < rates_total; i++)
     {
      // Merge Odd/Even logic continuously
      double current_vwap = (m_vwap_odd[i] != EMPTY_VALUE && m_vwap_odd[i] != 0) ? m_vwap_odd[i] : m_vwap_even[i];
      m_vwap_buf[i] = current_vwap;

      // If VWAP is newly reset (0 or empty), VScore is 0
      if(current_vwap == 0 || current_vwap == EMPTY_VALUE)
        {
         out_vscore[i] = 0.0;
         continue;
        }

      double sum_sq_diff = 0;

      // StdDev of deviation over the window
      for(int k = 0; k < m_period; k++)
        {
         int idx = i - k;
         double p = close[idx];
         double v = m_vwap_buf[idx];

         // If history has bad vwap, use price (diff=0) to avoid spikes
         if(v == 0 || v == EMPTY_VALUE)
            v = p;

         double diff = p - v;
         sum_sq_diff += diff * diff;
        }

      double std_dev = MathSqrt(sum_sq_diff / m_period);

      // Z-Score calculation
      if(std_dev > 1.0e-9)
         out_vscore[i] = (close[i] - current_vwap) / std_dev;
      else
         out_vscore[i] = 0.0;
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
