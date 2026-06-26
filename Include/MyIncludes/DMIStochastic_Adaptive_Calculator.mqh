//+------------------------------------------------------------------+
//|                             DMIStochastic_Adaptive_Calculator.mqh|
//|      VERSION 3.10: Dynamic Volume-Weighted MA Support (VWMA)     |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.10" // Refactored with overloaded Calculate to support VWMA slowing/signals

#ifndef DMISTOCHASTIC_ADAPTIVE_CALCULATOR_MQH
#define DMISTOCHASTIC_ADAPTIVE_CALCULATOR_MQH

#include <MyIncludes\DMI_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

enum ENUM_CANDLE_SOURCE { CANDLE_STANDARD, CANDLE_HEIKIN_ASHI };
enum ENUM_DMI_OSC_TYPE { OSC_PDI_MINUS_NDI, OSC_NDI_MINUS_PDI };

//+==================================================================+
//|             CLASS: CDMIStochasticAdaptiveCalculator              |
//+==================================================================+
class CDMIStochasticAdaptiveCalculator
  {
protected:
   CDMIEngine               *m_dmi_engine;
   CMovingAverageCalculator m_slowing_engine;
   CMovingAverageCalculator m_signal_engine;

   int               m_dmi_period;
   int               m_er_period, m_min_period, m_max_period;
   ENUM_DMI_OSC_TYPE m_osc_type;

   //--- Persistent Buffers
   double            m_pDI[], m_nDI[];
   double            m_dmiOsc[];
   double            m_er_buffer[];
   double            m_nsp_buffer[];
   double            m_raw_k[];

   virtual void      CreateEngine(void);

public:
                     CDMIStochasticAdaptiveCalculator(void);
   virtual          ~CDMIStochasticAdaptiveCalculator(void);

   bool              Init(int dmi_p, int er_p, int min_p, int max_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma, ENUM_DMI_OSC_TYPE osc_type);

   //--- Standard Calculate (Without volume)
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &k_buffer[], double &d_buffer[]);

   //--- NEW: Overloaded Calculate (With volume to support VWMA Slowing/Signal)
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &volume[],
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor / Destructor                                         |
//+------------------------------------------------------------------+
CDMIStochasticAdaptiveCalculator::CDMIStochasticAdaptiveCalculator(void) { m_dmi_engine = NULL; }
CDMIStochasticAdaptiveCalculator::~CDMIStochasticAdaptiveCalculator(void) { if(CheckPointer(m_dmi_engine) != POINTER_INVALID) delete m_dmi_engine; }

void CDMIStochasticAdaptiveCalculator::CreateEngine(void) { m_dmi_engine = new CDMIEngine(); }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CDMIStochasticAdaptiveCalculator::Init(int dmi_p, int er_p, int min_p, int max_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma, ENUM_DMI_OSC_TYPE osc_type)
  {
   m_dmi_period = (dmi_p < 1) ? 1 : dmi_p;
   m_er_period  = (er_p < 1) ? 1 : er_p;
   m_min_period = (min_p < 1) ? 1 : min_p;
   m_max_period = (max_p <= m_min_period) ? m_min_period + 1 : max_p;
   m_osc_type   = osc_type;

   CreateEngine();
   if(!m_dmi_engine.Init(m_dmi_period))
      return false;

   if(!m_slowing_engine.Init(slow_p, slow_ma))
      return false;

   if(!m_signal_engine.Init(d_p, d_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard - No Volume)                                 |
//+------------------------------------------------------------------+
void CDMIStochasticAdaptiveCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
   if(rates_total < m_dmi_period + MathMax(m_er_period, m_max_period))
      return;

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// Resize Internal Buffers
   if(ArraySize(m_pDI) != rates_total)
     {
      ArrayResize(m_pDI, rates_total);
      ArrayResize(m_nDI, rates_total);
      ArrayResize(m_dmiOsc, rates_total);
      ArrayResize(m_er_buffer, rates_total);
      ArrayResize(m_nsp_buffer, rates_total);
      ArrayResize(m_raw_k, rates_total);
     }

// 1. Calculate +DI and -DI using the DMI Engine
   m_dmi_engine.Calculate(rates_total, prev_calculated, open, high, low, close, m_pDI, m_nDI);

// 2. Calculate DMI Oscillator Line
   int loop_start_dmi = MathMax(m_dmi_period, start_index);
   for(int i = loop_start_dmi; i < rates_total; i++)
     {
      if(m_osc_type == OSC_PDI_MINUS_NDI)
         m_dmiOsc[i] = m_pDI[i] - m_nDI[i];
      else
         m_dmiOsc[i] = m_nDI[i] - m_pDI[i];
     }

// 3. Calculate Efficiency Ratio (ER) ON the DMI Oscillator line
   int er_start = m_dmi_period + m_er_period;
   int loop_start_er = MathMax(er_start, start_index);
   for(int i = loop_start_er; i < rates_total; i++)
     {
      double direction = MathAbs(m_dmiOsc[i] - m_dmiOsc[i - m_er_period]);
      double volatility = 0;
      for(int j = 0; j < m_er_period; j++)
        {
         volatility += MathAbs(m_dmiOsc[i - j] - m_dmiOsc[i - j - 1]);
        }
      m_er_buffer[i] = (volatility > 0.000001) ? direction / volatility : 0;
     }

// 4. Calculate Adaptive Period (NSP) based on ER
   for(int i = loop_start_er; i < rates_total; i++)
     {
      m_nsp_buffer[i] = (int)(m_er_buffer[i] * (m_max_period - m_min_period) + m_min_period);
      if(m_nsp_buffer[i] < 1)
         m_nsp_buffer[i] = 1;
     }

// 5. Calculate Raw %K with Dynamic Lookback (NSP)
   int raw_k_start = er_start + m_max_period - 1;
   int loop_start_k = MathMax(raw_k_start, start_index);
   for(int i = loop_start_k; i < rates_total; i++)
     {
      int current_nsp = (int)m_nsp_buffer[i];
      double highest = m_dmiOsc[i];
      double lowest  = m_dmiOsc[i];

      for(int j = 1; j < current_nsp; j++)
        {
         if(i - j < m_dmi_period)
            break;
         highest = MathMax(highest, m_dmiOsc[i-j]);
         lowest  = MathMin(lowest, m_dmiOsc[i-j]);
        }

      double range = highest - lowest;
      if(range > 0.000001)
         m_raw_k[i] = (m_dmiOsc[i] - lowest) / range * 100.0;
      else
         m_raw_k[i] = (i > raw_k_start) ? m_raw_k[i-1] : 50.0;
     }

// 6. Smooth Raw K to get Final %K (Slowing) (Without Volume)
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, k_buffer, raw_k_start);

// 7. Smooth Final %K to get Final %D (Signal) (Without Volume)
   int d_start = raw_k_start + m_slowing_engine.GetPeriod() - 1;
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, d_start);
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Volume for VWMA)                    |
//+------------------------------------------------------------------+
void CDMIStochasticAdaptiveCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
      const long &volume[],
      double &k_buffer[], double &d_buffer[])
  {
   if(rates_total < m_dmi_period + MathMax(m_er_period, m_max_period))
      return;

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// Resize Internal Buffers
   if(ArraySize(m_pDI) != rates_total)
     {
      ArrayResize(m_pDI, rates_total);
      ArrayResize(m_nDI, rates_total);
      ArrayResize(m_dmiOsc, rates_total);
      ArrayResize(m_er_buffer, rates_total);
      ArrayResize(m_nsp_buffer, rates_total);
      ArrayResize(m_raw_k, rates_total);
     }

// 1. Calculate +DI and -DI using the DMI Engine
   m_dmi_engine.Calculate(rates_total, prev_calculated, open, high, low, close, m_pDI, m_nDI);

// 2. Calculate DMI Oscillator Line
   int loop_start_dmi = MathMax(m_dmi_period, start_index);
   for(int i = loop_start_dmi; i < rates_total; i++)
     {
      if(m_osc_type == OSC_PDI_MINUS_NDI)
         m_dmiOsc[i] = m_pDI[i] - m_nDI[i];
      else
         m_dmiOsc[i] = m_nDI[i] - m_pDI[i];
     }

// 3. Calculate Efficiency Ratio (ER) ON the DMI Oscillator line
   int er_start = m_dmi_period + m_er_period;
   int loop_start_er = MathMax(er_start, start_index);
   for(int i = loop_start_er; i < rates_total; i++)
     {
      double direction = MathAbs(m_dmiOsc[i] - m_dmiOsc[i - m_er_period]);
      double volatility = 0;
      for(int j = 0; j < m_er_period; j++)
        {
         volatility += MathAbs(m_dmiOsc[i - j] - m_dmiOsc[i - j - 1]);
        }
      m_er_buffer[i] = (volatility > 0.000001) ? direction / volatility : 0;
     }

// 4. Calculate Adaptive Period (NSP) based on ER
   for(int i = loop_start_er; i < rates_total; i++)
     {
      m_nsp_buffer[i] = (int)(m_er_buffer[i] * (m_max_period - m_min_period) + m_min_period);
      if(m_nsp_buffer[i] < 1)
         m_nsp_buffer[i] = 1;
     }

// 5. Calculate Raw %K with Dynamic Lookback (NSP)
   int raw_k_start = er_start + m_max_period - 1;
   int loop_start_k = MathMax(raw_k_start, start_index);
   for(int i = loop_start_k; i < rates_total; i++)
     {
      int current_nsp = (int)m_nsp_buffer[i];
      double highest = m_dmiOsc[i];
      double lowest  = m_dmiOsc[i];

      for(int j = 1; j < current_nsp; j++)
        {
         if(i - j < m_dmi_period)
            break;
         highest = MathMax(highest, m_dmiOsc[i-j]);
         lowest  = MathMin(lowest, m_dmiOsc[i-j]);
        }

      double range = highest - lowest;
      if(range > 0.000001)
         m_raw_k[i] = (m_dmiOsc[i] - lowest) / range * 100.0;
      else
         m_raw_k[i] = (i > raw_k_start) ? m_raw_k[i-1] : 50.0;
     }

// 6. Convert long volume to double to support VWMA Slowing & Signal
   double vol_double[];
   ArrayResize(vol_double, rates_total);
   for(int j = start_index; j < rates_total; j++)
      vol_double[j] = (double)volume[j];

// 7. Smooth Raw K to get Final %K (Slowing with Volume)
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, vol_double, k_buffer, raw_k_start);

// 8. Smooth Final %K to get Final %D (Signal with Volume)
   int d_start = raw_k_start + m_slowing_engine.GetPeriod() - 1;
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, vol_double, d_buffer, d_start);
  }

//--- HA Subclass
class CDMIStochasticAdaptiveCalculator_HA : public CDMIStochasticAdaptiveCalculator
  {
protected:
   virtual void      CreateEngine(void) override { m_dmi_engine = new CDMIEngine_HA(); }
  };
#endif // DMISTOCHASTIC_ADAPTIVE_CALCULATOR_MQH
//+------------------------------------------------------------------+
