//+------------------------------------------------------------------+
//|                     Stochastic_Adaptive_on_DMI_Calculator.mqh    |
//|      Engine: Adaptive Stochastic applied to DMI Oscillator.      |
//|      VERSION 2.00: ER Calculated on DMI (Pure Logic).            |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\DMI_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Enums Definitions
#ifndef ENUM_CANDLE_SOURCE_DEFINED
#define ENUM_CANDLE_SOURCE_DEFINED
enum ENUM_CANDLE_SOURCE { CANDLE_STANDARD, CANDLE_HEIKIN_ASHI };
#endif

enum ENUM_DMI_OSC_TYPE { OSC_PDI_MINUS_NDI, OSC_NDI_MINUS_PDI };

//+==================================================================+
//| CLASS: CStochAdaptiveOnDMICalculator                             |
//+==================================================================+
class CStochAdaptiveOnDMICalculator
  {
protected:
   // Parameters
   int               m_dmi_p;
   ENUM_DMI_OSC_TYPE m_osc_type;
   int               m_er_p;
   int               m_min_stoch_p;
   int               m_max_stoch_p;

   // Engines
   CDMIEngine        *m_dmi_engine;
   CMovingAverageCalculator m_slowing_engine;
   CMovingAverageCalculator m_signal_engine;

   // Buffers
   double            m_pDI[], m_nDI[];
   double            m_dmi_osc[];    // DMI Oscillator
   double            m_er_buffer[];  // Efficiency Ratio of DMI
   double            m_nsp_buffer[]; // Dynamic Period
   double            m_raw_k[];      // Raw Adaptive %K

   // Factory Method
   virtual void      CreateDMIEngine();

public:
                     CStochAdaptiveOnDMICalculator();
   virtual          ~CStochAdaptiveOnDMICalculator();

   bool              Init(int dmi_p, ENUM_DMI_OSC_TYPE osc_type, int er_p, int min_p, int max_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma);

   void              Calculate(int rates_total, int prev_calculated,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               double &out_k[], double &out_d[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStochAdaptiveOnDMICalculator::CStochAdaptiveOnDMICalculator() : m_dmi_engine(NULL) {}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStochAdaptiveOnDMICalculator::~CStochAdaptiveOnDMICalculator()
  {
   if(CheckPointer(m_dmi_engine) == POINTER_DYNAMIC)
      delete m_dmi_engine;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStochAdaptiveOnDMICalculator::CreateDMIEngine()
  {
   m_dmi_engine = new CDMIEngine();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochAdaptiveOnDMICalculator::Init(int dmi_p, ENUM_DMI_OSC_TYPE osc_type, int er_p, int min_p, int max_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma)
  {
   m_dmi_p       = dmi_p;
   m_osc_type    = osc_type;
   m_er_p        = er_p;
   m_min_stoch_p = min_p;
   m_max_stoch_p = max_p;

   CreateDMIEngine();
   if(!m_dmi_engine.Init(m_dmi_p))
      return false;
   if(!m_slowing_engine.Init(slow_p, slow_ma))
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
   if(rates_total < m_dmi_p + m_er_p + m_max_stoch_p)
      return;

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// 1. Resize Buffers
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
   int loop_start_dmi = MathMax(m_dmi_p, start_index);
   for(int i = loop_start_dmi; i < rates_total; i++)
     {
      if(m_osc_type == OSC_PDI_MINUS_NDI)
         m_dmi_osc[i] = m_pDI[i] - m_nDI[i];
      else
         m_dmi_osc[i] = m_nDI[i] - m_pDI[i];
     }

// 4. Calculate Efficiency Ratio (ER) on DMI OSCILLATOR (Pure Logic)
   int loop_start_er = MathMax(m_dmi_p + m_er_p, start_index);

   for(int i = loop_start_er; i < rates_total; i++)
     {
      double direction = MathAbs(m_dmi_osc[i] - m_dmi_osc[i - m_er_p]);
      double volatility = 0;
      for(int j = 0; j < m_er_p; j++)
         volatility += MathAbs(m_dmi_osc[i - j] - m_dmi_osc[i - j - 1]);

      m_er_buffer[i] = (volatility > 1.0e-9) ? direction / volatility : 0.0;
     }

// 5. Calculate Adaptive Period (NSP)
   for(int i = loop_start_er; i < rates_total; i++)
     {
      m_nsp_buffer[i] = (int)MathRound(m_min_stoch_p + (1.0 - m_er_buffer[i]) * (m_max_stoch_p - m_min_stoch_p));
      if(m_nsp_buffer[i] < 2)
         m_nsp_buffer[i] = 2;
     }

// 6. Calculate Raw %K on DMI Oscillator
   int stoch_start = m_dmi_p + m_er_p + m_max_stoch_p - 1;
   int loop_start_k = MathMax(stoch_start, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      int current_nsp = (int)m_nsp_buffer[i];
      double highest = m_dmi_osc[i];
      double lowest = m_dmi_osc[i];

      for(int k = 1; k < current_nsp; k++)
        {
         if(i-k < 0)
            break;
         if(m_dmi_osc[i-k] > highest)
            highest = m_dmi_osc[i-k];
         if(m_dmi_osc[i-k] < lowest)
            lowest = m_dmi_osc[i-k];
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
//+------------------------------------------------------------------+
