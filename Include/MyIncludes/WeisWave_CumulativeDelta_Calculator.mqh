//+------------------------------------------------------------------+
//|                               WeisWave_CumulativeDelta_Calculator|
//|      Engine for Wyckoff Cumulative Wave Delta (Smart Money Flow) |
//|      Strictly O(1) Incremental Optimized.                        |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"

#ifndef WEISWAVE_CUMULATIVE_DELTA_CALCULATOR_MQH
#define WEISWAVE_CUMULATIVE_DELTA_CALCULATOR_MQH

//+==================================================================+
//|             CLASS: CWeisWaveDeltaCalculator                      |
//+==================================================================+
class CWeisWaveDeltaCalculator
  {
private:
   int               m_atr_period;
   double            m_multiplier;

   //--- Stateful arrays to prevent repainting (O(1) state preservation)
   int               m_direction[];
   double            m_peak_high[];
   double            m_peak_low[];
   double            m_cum_delta[]; // Holds the running cumulative net wave volume

   double            GetATR(int i, const double &high[], const double &low[], const double &close[]);

public:
                     CWeisWaveDeltaCalculator();
                    ~CWeisWaveDeltaCalculator() {};

   bool              Init(int atr_period, double multiplier);
   void              Calculate(int rates_total, int prev_calculated,
                               const double &high[], const double &low[], const double &close[], const long &volume[],
                               double &out_delta[], double &out_colors[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CWeisWaveDeltaCalculator::CWeisWaveDeltaCalculator() : m_atr_period(14), m_multiplier(2.5) {}

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CWeisWaveDeltaCalculator::Init(int atr_period, double multiplier)
  {
   m_atr_period = (atr_period < 3) ? 3 : atr_period;
   m_multiplier = (multiplier <= 0.0) ? 1.0 : multiplier;
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Strictly O(1) Non-Repainting Stateful Cumulative Delta)|
//+------------------------------------------------------------------+
void CWeisWaveDeltaCalculator::Calculate(int rates_total, int prev_calculated,
      const double &high[], const double &low[], const double &close[], const long &volume[],
      double &out_delta[], double &out_colors[])
  {
   if(rates_total < m_atr_period + 5)
      return;

//--- Sync state arrays with rates_total
   if(ArraySize(m_direction) != rates_total)
     {
      ArrayResize(m_direction, rates_total);
      ArrayResize(m_peak_high, rates_total);
      ArrayResize(m_peak_low, rates_total);
      ArrayResize(m_cum_delta, rates_total);
     }

   int start = (prev_calculated == 0) ? 0 : prev_calculated - 1;

//--- Initialization for the very first bar
   if(start == 0)
     {
      m_direction[0] = 1; // Default to Up wave
      m_peak_high[0] = high[0];
      m_peak_low[0]  = low[0];
      m_cum_delta[0] = (double)volume[0];

      out_delta[0]   = m_cum_delta[0];
      out_colors[0]  = 0.0;
      start = 1;
     }

//--- Stateful main loop
   for(int i = start; i < rates_total; i++)
     {
      int prev_dir    = m_direction[i-1];
      double prev_hi  = m_peak_high[i-1];
      double prev_lo  = m_peak_low[i-1];
      double prev_del = m_cum_delta[i-1];

      double atr = GetATR(i, high, low, close);
      double threshold = m_multiplier * atr;

      m_direction[i] = prev_dir;
      m_peak_high[i] = prev_hi;
      m_peak_low[i]  = prev_lo;

      if(prev_dir == 1) // Active UP Swing
        {
         m_cum_delta[i] = prev_del + (double)volume[i]; // Add volume for Up wave
         m_peak_high[i] = MathMax(prev_hi, high[i]);

         // Check for Reversal to Down Swing
         if(close[i] < m_peak_high[i] - threshold)
           {
            m_direction[i] = -1;
            m_peak_low[i]  = low[i];
            m_cum_delta[i] = prev_del - (double)volume[i]; // Reverse and subtract volume
           }
        }
      else // Active DOWN Swing
        {
         m_cum_delta[i] = prev_del - (double)volume[i]; // Subtract volume for Down wave
         m_peak_low[i] = MathMin(prev_lo, low[i]);

         // Check for Reversal to Up Swing
         if(close[i] > m_peak_low[i] + threshold)
           {
            m_direction[i] = 1;
            m_peak_high[i] = high[i];
            m_cum_delta[i] = prev_del + (double)volume[i]; // Reverse and add volume
           }
        }

      //--- Map cumulative delta and colors (0: Green/Rising, 1: Red/Falling)
      out_delta[i] = m_cum_delta[i];
      if(m_cum_delta[i] >= prev_del)
         out_colors[i] = 0.0; // Index 0: LimeGreen (Rising smart money pressure)
      else
         out_colors[i] = 1.0; // Index 1: Crimson (Falling smart money pressure)
     }
  }

//+------------------------------------------------------------------+
//| GetATR                                                           |
//+------------------------------------------------------------------+
double CWeisWaveDeltaCalculator::GetATR(int i, const double &high[], const double &low[], const double &close[])
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

#endif // WEISWAVE_CUMULATIVE_DELTA_CALCULATOR_MQH
//+------------------------------------------------------------------+
