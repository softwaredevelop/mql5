//+------------------------------------------------------------------+
//|                                     DMIStochastic_Calculator.mqh |
//|      VERSION 2.10: Separate MA type for Signal Line.             |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Enum for selecting the oscillator calculation formula ---
enum ENUM_DMI_OSC_TYPE
  {
   OSC_PDI_MINUS_NDI,  // Intuitive: High value = Bullish pressure
   OSC_NDI_MINUS_PDI   // Original: High value = Bearish pressure
  };

//+==================================================================+
//|             CLASS 1: CDMIStochasticCalculator                    |
//+==================================================================+
class CDMIStochasticCalculator
  {
protected:
   int               m_dmi_period;
   int               m_fast_k_period;
   int               m_slow_k_period;
   int               m_smooth_period;
   ENUM_DMI_OSC_TYPE m_osc_type;

   //--- Engines for Smoothing
   CMovingAverageCalculator m_slow_k_engine;
   CMovingAverageCalculator m_smooth_d_engine;

   //--- Persistent Buffers
   double            m_high[], m_low[], m_close[];
   double            m_pDM[], m_nDM[], m_TR[];
   double            m_smoothed_pDM[], m_smoothed_nDM[], m_smoothed_TR[];
   double            m_dmiOsc[];
   double            m_fastK[];

   virtual bool      PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CDMIStochasticCalculator(void) {};
   virtual          ~CDMIStochasticCalculator(void) {};

   //--- Init now takes separate MA types for K and D
   bool              Init(int dmi_p, int fast_k, int slow_k, int smooth_p, ENUM_MA_TYPE k_method, ENUM_MA_TYPE d_method, ENUM_DMI_OSC_TYPE osc_type);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CDMIStochasticCalculator::Init(int dmi_p, int fast_k, int slow_k, int smooth_p, ENUM_MA_TYPE k_method, ENUM_MA_TYPE d_method, ENUM_DMI_OSC_TYPE osc_type)
  {
   m_dmi_period    = (dmi_p < 1) ? 1 : dmi_p;
   m_fast_k_period = (fast_k < 1) ? 1 : fast_k;
   m_slow_k_period = (slow_k < 1) ? 1 : slow_k;
   m_smooth_period = (smooth_p < 1) ? 1 : smooth_p;
   m_osc_type      = osc_type;

// Initialize Engines with separate methods
   if(!m_slow_k_engine.Init(m_slow_k_period, k_method))
      return false;
   if(!m_smooth_d_engine.Init(m_smooth_period, d_method))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CDMIStochasticCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
   int required_bars = m_dmi_period + m_fast_k_period + m_slow_k_period + m_smooth_period;
   if(rates_total < required_bars)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_high) != rates_total)
     {
      ArrayResize(m_high, rates_total);
      ArrayResize(m_low, rates_total);
      ArrayResize(m_close, rates_total);

      ArrayResize(m_pDM, rates_total);
      ArrayResize(m_nDM, rates_total);
      ArrayResize(m_TR, rates_total);

      ArrayResize(m_smoothed_pDM, rates_total);
      ArrayResize(m_smoothed_nDM, rates_total);
      ArrayResize(m_smoothed_TR, rates_total);

      ArrayResize(m_dmiOsc, rates_total);
      ArrayResize(m_fastK, rates_total);
     }

   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

//--- 1. Calculate DM and TR (Incremental)
   int loop_start_dm = MathMax(1, start_index);

   for(int i = loop_start_dm; i < rates_total; i++)
     {
      double high_diff = m_high[i] - m_high[i-1];
      double low_diff  = m_low[i-1] - m_low[i];
      m_pDM[i] = (high_diff > low_diff && high_diff > 0) ? high_diff : 0;
      m_nDM[i] = (low_diff > high_diff && low_diff > 0) ? low_diff : 0;
      m_TR[i]  = MathMax(m_high[i], m_close[i-1]) - MathMin(m_low[i], m_close[i-1]);
     }

//--- 2. Calculate Smoothed DM/TR (Wilder's Smoothing)
   int loop_start_smooth = MathMax(m_dmi_period, start_index);

   for(int i = loop_start_smooth; i < rates_total; i++)
     {
      if(i == m_dmi_period)
        {
         // Initial Sum
         double sum_pDM = 0, sum_nDM = 0, sum_TR = 0;
         for(int j = 1; j <= m_dmi_period; j++)
           {
            sum_pDM += m_pDM[j];
            sum_nDM += m_nDM[j];
            sum_TR += m_TR[j];
           }
         m_smoothed_pDM[i] = sum_pDM;
         m_smoothed_nDM[i] = sum_nDM;
         m_smoothed_TR[i]  = sum_TR;
        }
      else
        {
         // Wilder's Smoothing: Prev - (Prev/N) + Curr
         m_smoothed_pDM[i] = m_smoothed_pDM[i-1] - (m_smoothed_pDM[i-1] / m_dmi_period) + m_pDM[i];
         m_smoothed_nDM[i] = m_smoothed_nDM[i-1] - (m_smoothed_nDM[i-1] / m_dmi_period) + m_nDM[i];
         m_smoothed_TR[i]  = m_smoothed_TR[i-1]  - (m_smoothed_TR[i-1] / m_dmi_period) + m_TR[i];
        }
     }

//--- 3. Calculate DI and DMI Oscillator
   for(int i = loop_start_smooth; i < rates_total; i++)
     {
      double pDI = 0, nDI = 0;
      if(m_smoothed_TR[i] != 0.0)
        {
         pDI = (m_smoothed_pDM[i] / m_smoothed_TR[i]) * 100.0;
         nDI = (m_smoothed_nDM[i] / m_smoothed_TR[i]) * 100.0;
        }

      if(m_osc_type == OSC_PDI_MINUS_NDI)
         m_dmiOsc[i] = pDI - nDI;
      else
         m_dmiOsc[i] = nDI - pDI;
     }

//--- 4. Calculate Fast %K on DMI Oscillator
   int fast_k_start = m_dmi_period + m_fast_k_period - 1;
   int loop_start_k = MathMax(fast_k_start, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      double highest = m_dmiOsc[i];
      double lowest = m_dmiOsc[i];

      for(int j = 1; j < m_fast_k_period; j++)
        {
         highest = MathMax(highest, m_dmiOsc[i-j]);
         lowest = MathMin(lowest, m_dmiOsc[i-j]);
        }

      double range = highest - lowest;
      m_fastK[i] = (range == 0.0) ? 50.0 : ((m_dmiOsc[i] - lowest) / range) * 100.0;
     }

//--- 5. Calculate Slow %K (Main Line) using Engine
   m_slow_k_engine.CalculateOnArray(rates_total, prev_calculated, m_fastK, k_buffer, fast_k_start);

//--- 6. Calculate %D (Signal Line) using Engine
   int d_start = fast_k_start + m_slow_k_engine.GetPeriod() - 1;
   m_smooth_d_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, d_start);
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CDMIStochasticCalculator::PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      m_high[i] = high[i];
      m_low[i]  = low[i];
      m_close[i] = close[i];
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CDMIStochasticCalculator_HA                 |
//+==================================================================+
class CDMIStochasticCalculator_HA : public CDMIStochasticCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CDMIStochasticCalculator_HA::PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
      ArrayResize(m_ha_open, rates_total);

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_high, m_low, m_close);
   return true;
  }
//+------------------------------------------------------------------+
