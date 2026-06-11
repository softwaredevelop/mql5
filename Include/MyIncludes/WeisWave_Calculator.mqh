//+------------------------------------------------------------------+
//|                                         WeisWave_Calculator.mqh  |
//|      Engine for Non-Repainting Weis Wave Volume (Wyckoff Supply) |
//|      Strictly O(1) Incremental Optimized.                        |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"

#ifndef WEISWAVE_CALCULATOR_MQH
#define WEISWAVE_CALCULATOR_MQH

//+==================================================================+
//|             CLASS: CWeisWaveCalculator                           |
//+==================================================================+
class CWeisWaveCalculator
  {
private:
   int               m_atr_period;
   double            m_multiplier;

   //--- Stateful arrays to prevent repainting (O(1) state preservation)
   int               m_direction[];
   double            m_wave_vol[];
   double            m_peak_high[];
   double            m_peak_low[];

   double            GetATR(int i, const double &high[], const double &low[], const double &close[]);

public:
                     CWeisWaveCalculator();
                    ~CWeisWaveCalculator() {};

   bool              Init(int atr_period, double multiplier);
   void              Calculate(int rates_total, int prev_calculated,
                               const double &high[], const double &low[], const double &close[], const long &volume[],
                               double &out_wave_vol[], double &out_colors[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CWeisWaveCalculator::CWeisWaveCalculator() : m_atr_period(14), m_multiplier(2.5) {}

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CWeisWaveCalculator::Init(int atr_period, double multiplier)
  {
   m_atr_period = (atr_period < 3) ? 3 : atr_period;
   m_multiplier = (multiplier <= 0.0) ? 1.0 : multiplier;
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Strictly O(1) Non-Repainting Stateful Loop)           |
//+------------------------------------------------------------------+
void CWeisWaveCalculator::Calculate(int rates_total, int prev_calculated,
                                    const double &high[], const double &low[], const double &close[], const long &volume[],
                                    double &out_wave_vol[], double &out_colors[])
  {
   if(rates_total < m_atr_period + 5)
      return;

//--- Sync state arrays with rates_total
   if(ArraySize(m_direction) != rates_total)
     {
      ArrayResize(m_direction, rates_total);
      ArrayResize(m_wave_vol, rates_total);
      ArrayResize(m_peak_high, rates_total);
      ArrayResize(m_peak_low, rates_total);
     }

   int start = (prev_calculated == 0) ? 0 : prev_calculated - 1;

//--- Initialization for the very first bar
   if(start == 0)
     {
      m_direction[0] = 1; // Default to Up wave
      m_wave_vol[0]  = (double)volume[0];
      m_peak_high[0] = high[0];
      m_peak_low[0]  = low[0];

      out_wave_vol[0] = m_wave_vol[0];
      out_colors[0]   = 0.0;
      start = 1;
     }

//--- Stateful main loop
   for(int i = start; i < rates_total; i++)
     {
      // Read preceding state to avoid historical calculations
      int prev_dir    = m_direction[i-1];
      double prev_vol = m_wave_vol[i-1];
      double prev_hi  = m_peak_high[i-1];
      double prev_lo  = m_peak_low[i-1];

      double atr = GetATR(i, high, low, close);
      double threshold = m_multiplier * atr;

      // Carry forward previous peak states as defaults
      m_direction[i] = prev_dir;
      m_peak_high[i] = prev_hi;
      m_peak_low[i]  = prev_lo;

      if(prev_dir == 1) // Active UP Swing
        {
         m_wave_vol[i]  = prev_vol + (double)volume[i];
         m_peak_high[i] = MathMax(prev_hi, high[i]);

         // Check if price fell below the peak minus ATR threshold (REVERSAL to Down Swing)
         if(close[i] < m_peak_high[i] - threshold)
           {
            m_direction[i] = -1;
            m_wave_vol[i]  = (double)volume[i]; // Reset volume for the new wave
            m_peak_low[i]  = low[i];
           }
        }
      else // Active DOWN Swing
        {
         m_wave_vol[i] = prev_vol + (double)volume[i];
         m_peak_low[i] = MathMin(prev_lo, low[i]);

         // Check if price rose above the trough plus ATR threshold (REVERSAL to Up Swing)
         if(close[i] > m_peak_low[i] + threshold)
           {
            m_direction[i] = 1;
            m_wave_vol[i]  = (double)volume[i]; // Reset volume for the new wave
            m_peak_high[i] = high[i];
           }
        }

      //--- Map states directly to visual indicator buffers
      if(m_direction[i] == 1)
        {
         out_wave_vol[i] = m_wave_vol[i]; // Up swing volume is plotted positive
         out_colors[i]   = 0.0;           // Index 0: DodgerBlue / Lime
        }
      else
        {
         out_wave_vol[i] = -m_wave_vol[i]; // Down swing volume is plotted negative
         out_colors[i]   = 1.0;            // Index 1: Crimson / Coral
        }
     }
  }

//+------------------------------------------------------------------+
//| GetATR (Self-contained rolling ATR calculation)                  |
//+------------------------------------------------------------------+
double CWeisWaveCalculator::GetATR(int i, const double &high[], const double &low[], const double &close[])
  {
   if(i < m_atr_period)
      return _Point * 10;

   double sum = 0.0;
   for(int k = 0; k < m_atr_period; k++)
     {
      double h = high[i - k];
      double l = low[i - k];
      double c_prev = close[i - k - 1];

      // True Range formula
      double tr = MathMax(h - l, MathMax(MathAbs(h - c_prev), MathAbs(l - c_prev)));
      sum += tr;
     }
   return sum / m_atr_period;
  }

#endif // WEISWAVE_CALCULATOR_MQH
//+------------------------------------------------------------------+
