//+------------------------------------------------------------------+
//|                                         SOT_Wave_Calculator.mqh  |
//|      Engine for Non-Repainting Shortening of the Thrust (SOT).   |
//|      Strictly O(1) Incremental Optimized.                        |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"

#ifndef SOT_WAVE_CALCULATOR_MQH
#define SOT_WAVE_CALCULATOR_MQH

//+==================================================================+
//|             CLASS: CSOTWaveCalculator                            |
//+==================================================================+
class CSOTWaveCalculator
  {
private:
   int               m_atr_period;
   double            m_multiplier;

   //--- Stateful arrays to prevent repainting (O(1) state preservation)
   int               m_direction[];
   double            m_wave_len[];
   double            m_peak_high[];
   double            m_peak_low[];

   double            GetATR(int i, const double &high[], const double &low[], const double &close[]);
   bool              GetLastCompletedLengths(int current_idx, int target_dir, double &out_lens[]);

public:
                     CSOTWaveCalculator();
                    ~CSOTWaveCalculator() {};

   bool              Init(int atr_period, double multiplier);
   void              Calculate(int rates_total, int prev_calculated,
                               const datetime &time[], const double &high[], const double &low[], const double &close[],
                               double &out_bull_sot[], double &out_bear_sot[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSOTWaveCalculator::CSOTWaveCalculator() : m_atr_period(14), m_multiplier(2.5) {}

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CSOTWaveCalculator::Init(int atr_period, double multiplier)
  {
   m_atr_period = (atr_period < 3) ? 3 : atr_period;
   m_multiplier = (multiplier <= 0.0) ? 1.0 : multiplier;
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Incremental state machine with SOT detection)         |
//+------------------------------------------------------------------+
void CSOTWaveCalculator::Calculate(int rates_total, int prev_calculated,
                                   const datetime &time[], const double &high[], const double &low[], const double &close[],
                                   double &out_bull_sot[], double &out_bear_sot[])
  {
   if(rates_total < m_atr_period + 10)
      return;

//--- Sync state arrays
   if(ArraySize(m_direction) != rates_total)
     {
      ArrayResize(m_direction, rates_total);
      ArrayResize(m_wave_len, rates_total);
      ArrayResize(m_peak_high, rates_total);
      ArrayResize(m_peak_low, rates_total);
     }

   int start = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(start == 0)
     {
      m_direction[0] = 1;
      m_wave_len[0]  = high[0] - low[0];
      m_peak_high[0] = high[0];
      m_peak_low[0]  = low[0];
      start = 1;
     }

   for(int i = start; i < rates_total; i++)
     {
      out_bull_sot[i] = EMPTY_VALUE;
      out_bear_sot[i] = EMPTY_VALUE;

      int prev_dir    = m_direction[i-1];
      double prev_hi  = m_peak_high[i-1];
      double prev_lo  = m_peak_low[i-1];

      double atr = GetATR(i, high, low, close);
      double threshold = m_multiplier * atr;

      m_direction[i] = prev_dir;
      m_peak_high[i] = prev_hi;
      m_peak_low[i]  = prev_lo;

      if(prev_dir == 1) // Active UP Swing
        {
         m_peak_high[i] = MathMax(prev_hi, high[i]);
         m_wave_len[i]  = m_peak_high[i] - prev_lo; // Height of current up-wave

         if(close[i] < m_peak_high[i] - threshold) // REVERSAL to Down Swing
           {
            m_direction[i] = -1;
            m_peak_low[i]  = low[i];
            m_wave_len[i]  = m_peak_high[i] - m_peak_low[i];

            //--- SOT Check: Verify if completed UP wave shows Shortening of Thrust
            double h_lens[3];
            if(GetLastCompletedLengths(i - 1, 1, h_lens))
              {
               if(h_lens[0] < h_lens[1] && h_lens[1] < h_lens[2])
                 {
                  // Bearish SOT detected! Find exact peak bar of the completed up-wave to draw arrow
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
         m_peak_low[i] = MathMin(prev_lo, low[i]);
         m_wave_len[i] = prev_hi - m_peak_low[i]; // Height of current down-wave

         if(close[i] > m_peak_low[i] + threshold) // REVERSAL to Up Swing
           {
            m_direction[i] = 1;
            m_peak_high[i] = high[i];
            m_wave_len[i]  = m_peak_high[i] - m_peak_low[i];

            //--- SOT Check: Verify if completed DOWN wave shows Shortening of Thrust
            double l_lens[3];
            if(GetLastCompletedLengths(i - 1, -1, l_lens))
              {
               if(l_lens[0] < l_lens[1] && l_lens[1] < l_lens[2])
                 {
                  // Bullish SOT detected! Find exact trough bar of the completed down-wave to draw arrow
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
//| GetLastCompletedLengths (Historical state backward-search)        |
//+------------------------------------------------------------------+
bool CSOTWaveCalculator::GetLastCompletedLengths(int current_idx, int target_dir, double &out_lens[])
  {
   int found = 0;
   bool in_target_wave = false;
   ArrayInitialize(out_lens, 0.0);

   for(int j = current_idx; j >= 0; j--)
     {
      int dir = m_direction[j];
      if(dir == target_dir)
        {
         if(!in_target_wave)
           {
            in_target_wave = true;
            out_lens[found] = m_wave_len[j]; // Capture locked final wave height
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
double CSOTWaveCalculator::GetATR(int i, const double &high[], const double &low[], const double &close[])
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

#endif // SOT_WAVE_CALCULATOR_MQH
//+------------------------------------------------------------------+
