//+------------------------------------------------------------------+
//|                                   WeisWave_Duration_Calculator.mqh|
//|      Engine for Non-Repainting Weis Wave Duration (Time/Bars).   |
//|      Strictly O(1) Incremental Optimized.                        |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Fully commented and documented optimization structures

#ifndef WEISWAVE_DURATION_CALCULATOR_MQH
#define WEISWAVE_DURATION_CALCULATOR_MQH

//+==================================================================+
//|             CLASS: CWeisWaveDurationCalculator                   |
//+==================================================================+
class CWeisWaveDurationCalculator
  {
private:
   int               m_atr_period;
   double            m_multiplier;

   //--- Stateful persistent arrays for O(1) memory caching (Prevents Repainting)
   int               m_direction[];
   int               m_wave_dur[];   // Running bar count of the active wave
   double            m_peak_high[];  // Locks the peak high of the active up-wave
   double            m_peak_low[];   // Locks the trough low of the active down-wave

   double            GetATR(int i, const double &high[], const double &low[], const double &close[]);

public:
                     CWeisWaveDurationCalculator();
                    ~CWeisWaveDurationCalculator() {};

   bool              Init(int atr_period, double multiplier);
   void              Calculate(int rates_total, int prev_calculated,
                               const double &high[], const double &low[], const double &close[],
                               double &out_wave_dur[], double &out_colors[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CWeisWaveDurationCalculator::CWeisWaveDurationCalculator() : m_atr_period(14), m_multiplier(2.5) {}

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CWeisWaveDurationCalculator::Init(int atr_period, double multiplier)
  {
   m_atr_period = (atr_period < 3) ? 3 : atr_period;
   m_multiplier = (multiplier <= 0.0) ? 1.0 : multiplier;
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Strictly O(1) Non-Repainting Stateful Duration Loop)  |
//+------------------------------------------------------------------+
void CWeisWaveDurationCalculator::Calculate(int rates_total, int prev_calculated,
      const double &high[], const double &low[], const double &close[],
      double &out_wave_dur[], double &out_colors[])
  {
   if(rates_total < m_atr_period + 5)
      return;

//--- Dynamic array allocation: resized ONLY when bar count changes (ultra-fast)
   if(ArraySize(m_direction) != rates_total)
     {
      ArrayResize(m_direction, rates_total);
      ArrayResize(m_wave_dur, rates_total);
      ArrayResize(m_peak_high, rates_total);
      ArrayResize(m_peak_low, rates_total);
     }

//--- O(1) Optimization: Determine the exact starting index
//--- On first run (prev_calculated == 0), start is 0 (full historical calculation)
//--- On subsequent live ticks, start is rates_total - 1 (calculates only the current forming bar)
   int start = (prev_calculated == 0) ? 0 : prev_calculated - 1;

//--- First bar initialization
   if(start == 0)
     {
      m_direction[0] = 1;
      m_wave_dur[0]  = 1;
      m_peak_high[0] = high[0];
      m_peak_low[0]  = low[0];

      out_wave_dur[0] = (double)m_wave_dur[0];
      out_colors[0]   = 0.0;
      start = 1;
     }

//--- Stateful main calculation loop
   for(int i = start; i < rates_total; i++)
     {
      //--- Read locked states of the previous bar (i-1) to eliminate loop recalculations
      int prev_dir  = m_direction[i-1];
      int prev_dur  = m_wave_dur[i-1];
      double prev_hi  = m_peak_high[i-1];
      double prev_lo  = m_peak_low[i-1];

      double atr = GetATR(i, high, low, close);
      double threshold = m_multiplier * atr;

      //--- Set default state assumptions from previous bar
      m_direction[i] = prev_dir;
      m_peak_high[i] = prev_hi;
      m_peak_low[i]  = prev_lo;

      if(prev_dir == 1) // Active UP Swing
        {
         m_wave_dur[i]  = prev_dur + 1; // Increment duration
         m_peak_high[i] = MathMax(prev_hi, high[i]);

         // Reversal Check: If close price drops below threshold, reset and reverse
         if(close[i] < m_peak_high[i] - threshold)
           {
            m_direction[i] = -1;
            m_wave_dur[i]  = 1; // Reset duration to 1 for the new wave
            m_peak_low[i]  = low[i];
           }
        }
      else // Active DOWN Swing
        {
         m_wave_dur[i]  = prev_dur + 1; // Increment duration
         m_peak_low[i] = MathMin(prev_lo, low[i]);

         // Reversal Check: If close price rises above threshold, reset and reverse
         if(close[i] > m_peak_low[i] + threshold)
           {
            m_direction[i] = 1;
            m_wave_dur[i]  = 1; // Reset duration to 1 for the new wave
            m_peak_high[i] = high[i];
           }
        }

      //--- Render calculated state to indicator output buffers
      if(m_direction[i] == 1)
        {
         out_wave_dur[i] = (double)m_wave_dur[i]; // Up wave is positive
         out_colors[i]   = 0.0;                  // Color Index 0 (DodgerBlue)
        }
      else
        {
         out_wave_dur[i] = -(double)m_wave_dur[i]; // Down wave is negative
         out_colors[i]   = 1.0;                   // Color Index 1 (Crimson)
        }
     }
  }

//+------------------------------------------------------------------+
//| GetATR (Self-contained rolling ATR calculation)                  |
//+------------------------------------------------------------------+
double CWeisWaveDurationCalculator::GetATR(int i, const double &high[], const double &low[], const double &close[])
  {
   if(i < m_atr_period)
      return _Point * 10;

   double sum = 0.0;
   for(int k = 0; k < m_atr_period; k++)
     {
      double h = high[i - k];
      double l = low[i - k];
      double c_prev = close[i - k - 1];
      double tr = MathMax(h - l, MathMax(MathAbs(h - c_prev), MathAbs(l - c_prev)));
      sum += tr;
     }
   return sum / m_atr_period;
  }

#endif // WEISWAVE_DURATION_CALCULATOR_MQH
//+------------------------------------------------------------------+
