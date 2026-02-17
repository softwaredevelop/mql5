//+------------------------------------------------------------------+
//|                     Stochastic_Adaptive_on_DMI_Calculator.mqh    |
//|      Engine: Adaptive Stochastic applied to DMI Oscillator.      |
//|      Concept: Combines DMI trend strength with Adaptive Logic.   |
//|      VERSION 1.10: Added Safe Enum Definitions (Guards)          |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\DMI_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Enum for Candle Source (Safe Definition)
#ifndef ENUM_CANDLE_SOURCE_DEFINED
#define ENUM_CANDLE_SOURCE_DEFINED
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,
   CANDLE_HEIKIN_ASHI
  };
#endif

//--- Enum for DMI Osc Type (Safe Definition)
#ifndef ENUM_DMI_ADAPTIVE_OSC_TYPE_DEFINED
#define ENUM_DMI_ADAPTIVE_OSC_TYPE_DEFINED
enum ENUM_DMI_ADAPTIVE_OSC_TYPE
  {
   OSC_PDI_MINUS_NDI,
   OSC_NDI_MINUS_PDI
  };
#endif

//+==================================================================+
//| CLASS: CStochAdaptiveOnDMICalculator                             |
//+==================================================================+
class CStochAdaptiveOnDMICalculator
  {
protected:
   //--- Components
   CDMIEngine              *m_dmi_engine;
   CMovingAverageCalculator m_slowing_engine;
   CMovingAverageCalculator m_signal_engine;

   bool                     m_is_ha;

   //--- Parameters
   int                      m_dmi_p;
   int                      m_er_p;
   int                      m_min_stoch_p;
   int                      m_max_stoch_p;
   ENUM_DMI_ADAPTIVE_OSC_TYPE m_osc_type;

   //--- Internal Buffers
   double                   m_pDI[];
   double                   m_nDI[];
   double                   m_dmi_osc[];    // The "Source Price"
   double                   m_er_buffer[];  // Efficiency Ratio
   double                   m_nsp_buffer[]; // Dynamic Period
   double                   m_raw_k[];      // Raw Adaptive %K

   //--- Factory Method
   virtual void             CreateDMIEngine();

public:
                     CStochAdaptiveOnDMICalculator();
   virtual                 ~CStochAdaptiveOnDMICalculator();

   bool                     Init(int dmi_period, int er_period, int min_stoch, int max_stoch,
                                 int slow_k, ENUM_MA_TYPE slow_ma,
                                 int d_p, ENUM_MA_TYPE d_ma,
                                 ENUM_DMI_ADAPTIVE_OSC_TYPE osc_type);

   void                     Calculate(int rates_total, int prev_calculated,
                                      const double &open[], const double &high[],
                                      const double &low[], const double &close[],
                                      double &out_k[], double &out_d[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStochAdaptiveOnDMICalculator::CStochAdaptiveOnDMICalculator() : m_dmi_engine(NULL), m_is_ha(false)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStochAdaptiveOnDMICalculator::~CStochAdaptiveOnDMICalculator()
  {
   if(CheckPointer(m_dmi_engine) == POINTER_DYNAMIC)
      delete m_dmi_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method (Standard)                                        |
//+------------------------------------------------------------------+
void CStochAdaptiveOnDMICalculator::CreateDMIEngine()
  {
   m_dmi_engine = new CDMIEngine();
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CStochAdaptiveOnDMICalculator::Init(int dmi_period, int er_period, int min_stoch, int max_stoch,
      int slow_k, ENUM_MA_TYPE slow_ma,
      int d_p, ENUM_MA_TYPE d_ma,
      ENUM_DMI_ADAPTIVE_OSC_TYPE osc_type)
  {
   m_dmi_p       = dmi_period;
   m_er_p        = (er_period < 1) ? 1 : er_period;
   m_min_stoch_p = (min_stoch < 2) ? 2 : min_stoch;
   m_max_stoch_p = (max_stoch <= m_min_stoch_p) ? m_min_stoch_p + 1 : max_stoch;
   m_osc_type    = osc_type;

   CreateDMIEngine();
   if(!m_dmi_engine.Init(m_dmi_p))
      return false;

// Initialize MA Engines for smoothing
   if(!m_slowing_engine.Init(slow_k, slow_ma))
      return false;
   if(!m_signal_engine.Init(d_p, d_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CStochAdaptiveOnDMICalculator::Calculate(int rates_total, int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &out_k[], double &out_d[])
  {
// Safety check: DMI Period + ER Period + Smoothing
   if(rates_total < m_dmi_p + m_er_p + m_max_stoch_p)
      return;

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// 1. Resize Internal Buffers
   if(ArraySize(m_pDI) != rates_total)
     {
      ArrayResize(m_pDI, rates_total);
      ArrayResize(m_nDI, rates_total);
      ArrayResize(m_dmi_osc, rates_total);
      ArrayResize(m_er_buffer, rates_total);
      ArrayResize(m_nsp_buffer, rates_total);
      ArrayResize(m_raw_k, rates_total);
     }

// 2. Calculate Base DMI
   m_dmi_engine.Calculate(rates_total, prev_calculated, open, high, low, close, m_pDI, m_nDI);

// 3. Calculate DMI Oscillator
   int loop_start = MathMax(m_dmi_p, start_index);
   for(int i = loop_start; i < rates_total; i++)
     {
      if(m_osc_type == OSC_PDI_MINUS_NDI)
         m_dmi_osc[i] = m_pDI[i] - m_nDI[i];
      else
         m_dmi_osc[i] = m_nDI[i] - m_pDI[i];
     }

// 4. Calculate Efficiency Ratio (ER) on DMI Oscillator
   int er_start = m_dmi_p + m_er_p;
   loop_start = MathMax(er_start, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double direction = MathAbs(m_dmi_osc[i] - m_dmi_osc[i - m_er_p]);
      double volatility = 0;
      for(int j = 0; j < m_er_p; j++)
         volatility += MathAbs(m_dmi_osc[i - j] - m_dmi_osc[i - j - 1]);

      m_er_buffer[i] = (volatility > 1.0e-9) ? direction / volatility : 0.0;
     }

// 5. Calculate Adaptive Period (NSP)
   for(int i = loop_start; i < rates_total; i++)
     {
      m_nsp_buffer[i] = (int)MathRound(m_min_stoch_p + (1.0 - m_er_buffer[i]) * (m_max_stoch_p - m_min_stoch_p));
      if(m_nsp_buffer[i] < 2)
         m_nsp_buffer[i] = 2;
     }

// 6. Calculate Raw %K on DMI Oscillator
   int stoch_start = er_start + m_max_stoch_p;
   loop_start = MathMax(stoch_start, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      int current_nsp = (int)m_nsp_buffer[i];

      double highest = m_dmi_osc[i];
      double lowest  = m_dmi_osc[i];

      // Dynamic Lookback
      for(int k = 1; k < current_nsp; k++)
        {
         if(i - k < 0)
            break;
         highest = MathMax(highest, m_dmi_osc[i - k]);
         lowest  = MathMin(lowest, m_dmi_osc[i - k]);
        }

      double range = highest - lowest;

      if(range > 1.0e-9)
         m_raw_k[i] = 100.0 * (m_dmi_osc[i] - lowest) / range;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i-1] : 50.0;
     }

// 7. Smoothing
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, out_k, stoch_start);

   int d_offset = stoch_start + m_slowing_engine.GetPeriod() - 1;
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, out_k, out_d, d_offset);
  }

//+==================================================================+
//| CLASS: CStochAdaptiveOnDMICalculator_HA (Heikin Ashi)            |
//+==================================================================+
class CStochAdaptiveOnDMICalculator_HA : public CStochAdaptiveOnDMICalculator
  {
protected:
   virtual void      CreateDMIEngine() override
     {
      m_dmi_engine = new CDMIEngine_HA();
     }
  };
//+------------------------------------------------------------------+
