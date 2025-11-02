//+------------------------------------------------------------------+
//|                                     DMIStochastic_Calculator.mqh |
//|          Calculation engine for Barbara Star's DMI Stochastic.   |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Enum for selecting the candle source for calculation ---
// Moved here to be visible for both .mqh and .mq5 files
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Enum for selecting the oscillator calculation formula ---
// Moved here to be visible for both .mqh and .mq5 files
enum ENUM_DMI_OSC_TYPE
  {
   OSC_PDI_MINUS_NDI,  // Intuitive: High value = Bullish pressure
   OSC_NDI_MINUS_PDI   // Original: High value = Bearish pressure
  };

//+==================================================================+
//|                                                                  |
//|                 CLASS DEFINITIONS (Forward Declarations)         |
//|                                                                  |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CDMIStochasticCalculator
  {
protected:
   //--- Input parameters
   int               m_dmi_period;
   int               m_fast_k_period;
   int               m_slow_k_period;
   int               m_smooth_period;
   ENUM_MA_METHOD    m_stoch_method;
   ENUM_DMI_OSC_TYPE m_osc_type;

   //--- Price buffers
   double            m_high[], m_low[], m_close[];

   //--- Private helper for calculating moving averages on an array
   void              CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_METHOD method, int start_pos);

   //--- Virtual method for preparing price data
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CDMIStochasticCalculator(void) {};
   virtual          ~CDMIStochasticCalculator(void) {};

   //--- Public interface
   bool              Init(int dmi_p, int fast_k, int slow_k, int smooth_p, ENUM_MA_METHOD method, ENUM_DMI_OSC_TYPE osc_type);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CDMIStochasticCalculator_HA : public CDMIStochasticCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+==================================================================+
//|                                                                  |
//|            METHOD IMPLEMENTATIONS: CDMIStochasticCalculator      |
//|                                                                  |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CDMIStochasticCalculator::Init(int dmi_p, int fast_k, int slow_k, int smooth_p, ENUM_MA_METHOD method, ENUM_DMI_OSC_TYPE osc_type)
  {
   m_dmi_period    = (dmi_p < 1) ? 1 : dmi_p;
   m_fast_k_period = (fast_k < 1) ? 1 : fast_k;
   m_slow_k_period = (slow_k < 1) ? 1 : slow_k;
   m_smooth_period = (smooth_p < 1) ? 1 : smooth_p;
   m_stoch_method  = method;
   m_osc_type      = osc_type;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CDMIStochasticCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
   int required_bars = m_dmi_period + m_fast_k_period + m_slow_k_period + m_smooth_period;
   if(rates_total < required_bars)
      return;
   if(!PreparePriceSeries(rates_total, open, high, low, close))
      return;

   double pDM[], nDM[], TR[], smoothed_pDM[], smoothed_nDM[], smoothed_TR[];
   double pDI[], nDI[], dmiOsc[], fastK[];
   ArrayResize(pDM, rates_total, 0);
   ArrayResize(nDM, rates_total, 0);
   ArrayResize(TR, rates_total, 0);
   ArrayResize(smoothed_pDM, rates_total, 0);
   ArrayResize(smoothed_nDM, rates_total, 0);
   ArrayResize(smoothed_TR, rates_total, 0);
   ArrayResize(pDI, rates_total, 0);
   ArrayResize(nDI, rates_total, 0);
   ArrayResize(dmiOsc, rates_total, 0);
   ArrayResize(fastK, rates_total, 0);

   for(int i = 1; i < rates_total; i++)
     {
      double high_diff = m_high[i] - m_high[i-1];
      double low_diff  = m_low[i-1] - m_low[i];
      pDM[i] = (high_diff > low_diff && high_diff > 0) ? high_diff : 0;
      nDM[i] = (low_diff > high_diff && low_diff > 0) ? low_diff : 0;
      TR[i]  = MathMax(m_high[i], m_close[i-1]) - MathMin(m_low[i], m_close[i-1]);
     }

   for(int i = m_dmi_period; i < rates_total; i++)
     {
      if(i == m_dmi_period)
        {
         for(int j = 1; j <= m_dmi_period; j++)
           {
            smoothed_pDM[i] += pDM[j];
            smoothed_nDM[i] += nDM[j];
            smoothed_TR[i] += TR[j];
           }
        }
      else
        {
         smoothed_pDM[i] = smoothed_pDM[i-1] - (smoothed_pDM[i-1] / m_dmi_period) + pDM[i];
         smoothed_nDM[i] = smoothed_nDM[i-1] - (smoothed_nDM[i-1] / m_dmi_period) + nDM[i];
         smoothed_TR[i]  = smoothed_TR[i-1]  - (smoothed_TR[i-1] / m_dmi_period) + TR[i];
        }
     }

   for(int i = m_dmi_period; i < rates_total; i++)
     {
      if(smoothed_TR[i] != 0.0)
        {
         pDI[i] = (smoothed_pDM[i] / smoothed_TR[i]) * 100.0;
         nDI[i] = (smoothed_nDM[i] / smoothed_TR[i]) * 100.0;
        }

      if(m_osc_type == OSC_PDI_MINUS_NDI)
         dmiOsc[i] = pDI[i] - nDI[i];
      else
         dmiOsc[i] = nDI[i] - pDI[i];
     }

   for(int i = m_dmi_period + m_fast_k_period - 1; i < rates_total; i++)
     {
      double highest = dmiOsc[i], lowest = dmiOsc[i];
      for(int j = 1; j < m_fast_k_period; j++)
        {
         highest = MathMax(highest, dmiOsc[i-j]);
         lowest = MathMin(lowest, dmiOsc[i-j]);
        }
      double range = highest - lowest;
      fastK[i] = (range == 0.0) ? 50.0 : ((dmiOsc[i] - lowest) / range) * 100.0;
     }

   int k_start = m_dmi_period + m_fast_k_period + m_slow_k_period - 2;
   CalculateMA(fastK, k_buffer, m_slow_k_period, m_stoch_method, k_start);

   int d_start = k_start + m_smooth_period - 1;
   CalculateMA(k_buffer, d_buffer, m_smooth_period, m_stoch_method, d_start);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CDMIStochasticCalculator::CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_METHOD method, int start_pos)
  {
   for(int i = start_pos; i < ArraySize(source_array); i++)
     {
      switch(method)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == start_pos)
              {
               double sum = 0;
               for(int j = 0; j < period; j++)
                  sum += source_array[i-j];
               dest_array[i] = sum / period;
              }
            else
              {
               if(method == MODE_EMA)
                 {
                  double pr = 2.0 / (period + 1.0);
                  dest_array[i] = source_array[i] * pr + dest_array[i-1] * (1.0 - pr);
                 }
               else
                  dest_array[i] = (dest_array[i-1] * (period - 1) + source_array[i]) / period;
              }
            break;
         case MODE_LWMA:
           {
            double sum = 0, w_sum = 0;
            for(int j = 0; j < period; j++)
              {
               int w = period - j;
               sum += source_array[i-j] * w;
               w_sum += w;
              }
            if(w_sum > 0)
               dest_array[i] = sum / w_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum = 0;
            for(int j = 0; j < period; j++)
               sum += source_array[i-j];
            dest_array[i] = sum / period;
           }
         break;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CDMIStochasticCalculator::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_high, rates_total);
   ArrayResize(m_low, rates_total);
   ArrayResize(m_close, rates_total);
   ArrayCopy(m_high, high, 0, 0, rates_total);
   ArrayCopy(m_low, low, 0, 0, rates_total);
   ArrayCopy(m_close, close, 0, 0, rates_total);
   return true;
  }

//+==================================================================+
//|                                                                  |
//|          METHOD IMPLEMENTATIONS: CDMIStochasticCalculator_HA     |
//|                                                                  |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CDMIStochasticCalculator_HA::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_high, rates_total);
   ArrayResize(m_low, rates_total);
   ArrayResize(m_close, rates_total);
   ArrayCopy(m_high, ha_high, 0, 0, rates_total);
   ArrayCopy(m_low, ha_low, 0, 0, rates_total);
   ArrayCopy(m_close, ha_close, 0, 0, rates_total);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
