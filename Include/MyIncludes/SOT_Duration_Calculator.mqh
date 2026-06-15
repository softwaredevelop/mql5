//+------------------------------------------------------------------+
//|                                         SOT_Duration_Calculator.mqh |
//|      Engine for Non-Repainting Temporal SOT (Duration-based).    |
//|      Strictly O(1) Incremental Optimized.                        |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"

#ifndef SOT_DURATION_CALCULATOR_MQH
#define SOT_DURATION_CALCULATOR_MQH

//+==================================================================+
//|             CLASS: CSOTDurationCalculator                        |
//+==================================================================+
class CSOTDurationCalculator
  {
private:
   int               m_atr_period;
   double            m_multiplier;

   //--- Stateful arrays to prevent repainting (O(1) state preservation)
   int               m_direction[];
   int               m_wave_dur[];   // Running bar count of the active wave
   double            m_peak_high[];
   double            m_peak_low[];

   double            GetATR(int i, const double &high[], const double &low[], const double &close[]);
   bool              GetLastCompletedDurations(int current_idx, int target_dir, double &out_durs[]);

public:
                     CSOTDurationCalculator();
                    ~CSOTDurationCalculator() {};

   bool              Init(int atr_period, double multiplier);
   void              Calculate(int rates_total, int prev_calculated,
                               const datetime &time[], const double &high[], const double &low[], const double &close[],
                               double &out_bull_sot[], double &out_bear_sot[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
//--- Default initialization
CSOTDurationCalculator::CSOTDurationCalculator() : m_atr_period(14), m_multiplier(2.5) {}

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CSOTDurationCalculator::Init(int atr_period, double multiplier)
  {
   m_atr_period = (atr_period < 3) ? 3 : atr_period;
   m_multiplier = (multiplier <= 0.0) ? 1.0 : multiplier;
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Incremental state machine with temporal SOT)          |
//+------------------------------------------------------------------+
void CSOTDurationCalculator::Calculate(int rates_total, int prev_calculated,
                                       const datetime &time[], const double &high[], const double &low[], const double &close[],
                                       double &out_bull_sot[], double &out_bear_sot[])
  {
   if(rates_total < m_atr_period + 10)
      return;

//--- Sync state arrays
   if(ArraySize(m_direction) != rates_total)
     {
      ArrayResize(m_direction, rates_total);
      ArrayResize(m_wave_dur, rates_total);
      ArrayResize(m_peak_high, rates_total);
      ArrayResize(m_peak_low, rates_total);
     }

   int start = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(start == 0)
     {
      m_direction[0] = 1;
      m_wave_dur[0]  = 1;
      m_peak_high[0] = high[0];
      m_peak_low[0]  = low[0];
      start = 1;
     }

   for(int i = start; i < rates_total; i++)
     {
      out_bull_sot[i] = EMPTY_VALUE;
      out_bear_sot[i] = EMPTY_VALUE;

      int prev_dir    = m_direction[i-1];
      int prev_dur    = m_wave_dur[i-1];
      double prev_hi  = m_peak_high[i-1];
      double prev_lo  = m_peak_low[i-1];

      double atr = GetATR(i, high, low, close);
      double threshold = m_multiplier * atr;

      m_direction[i] = prev_dir;
      m_peak_high[i] = prev_hi;
      m_peak_low[i]  = prev_lo;

      if(prev_dir == 1) // Active UP Swing
        {
         m_wave_dur[i]  = prev_dur + 1; // Increment duration
         m_peak_high[i] = MathMax(prev_hi, high[i]);

         if(close[i] < m_peak_high[i] - threshold) // REVERSAL to Down Swing
           {
            m_direction[i] = -1;
            m_peak_low[i]  = low[i];
            m_wave_dur[i]  = 1;

            //--- SOT Check: Verify if completed UP wave shows Shortening of Duration (Time)
            double h_durs[3];
            if(GetLastCompletedDurations(i - 1, 1, h_durs))
              {
               if(h_durs[0] < h_durs[1] && h_durs[1] < h_durs[2])
                 {
                  // Bearish Duration SOT detected! Find exact peak bar of the completed up-wave
                  for(int k = i - 1; k >= 0; k--)
                    {
                     if(m_direction[k] == 1 && high[k] == prev_hi)
                       {
                        out_bear_sot[k] = high[k] + atr * 0.3; // Place Red Arrow above peak
                        break;
                       }
                     if(m_direction[k] != 1)
                        break;
                    }
                 }
              }
           }
        }
      else // Active DOWN Swing
        {
         m_wave_dur[i]  = prev_dur + 1; // Increment duration
         m_peak_low[i]  = MathMin(prev_lo, low[i]);

         if(close[i] > m_peak_low[i] + threshold) // REVERSAL to Up Swing
           {
            m_direction[i] = 1;
            m_peak_high[i] = high[i];
            m_wave_dur[i]  = 1;

            //--- SOT Check: Verify if completed DOWN wave shows Shortening of Duration (Time)
            double l_durs[3];
            if(GetLastCompletedDurations(i - 1, -1, l_durs))
              {
               if(l_durs[0] < l_durs[1] && l_durs[1] < l_durs[2])
                 {
                  // Bullish Duration SOT detected! Find exact trough bar of the completed down-wave
                  for(int k = i - 1; k >= 0; k--)
                    {
                     if(m_direction[k] == -1 && low[k] == prev_lo)
                       {
                        out_bull_sot[k] = low[k] - atr * 0.3; // Place Green Arrow below trough
                        break;
                       }
                     if(m_direction[k] != -1)
                        break;
                    }
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| GetLastCompletedDurations                                        |
//+------------------------------------------------------------------+
bool CSOTDurationCalculator::GetLastCompletedDurations(int current_idx, int target_dir, double &out_durs[])
  {
   int found = 0;
   bool in_target_wave = false;
   ArrayInitialize(out_durs, 0.0);

   for(int j = current_idx; j >= 0; j--)
     {
      int dir = m_direction[j];
      if(dir == target_dir)
        {
         if(!in_target_wave)
           {
            in_target_wave = true;
            out_durs[found] = (double)m_wave_dur[j]; // Capture locked final wave duration
            found++;
            if(found >= 3)
               return true;
           }
        }
      else
        {
         in_target_wave = false;
        }
     }
   return (found >= 3);
  }

//+------------------------------------------------------------------+
//| GetATR                                                           |
//+------------------------------------------------------------------+
double CSOTDurationCalculator::GetATR(int i, const double &high[], const double &low[], const double &close[])
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

#endif // SOT_DURATION_CALCULATOR_MQH
//+------------------------------------------------------------------+
