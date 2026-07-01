//+------------------------------------------------------------------+
//|                     Stochastic_Adaptive_on_DMI_Calculator.mqh    |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.20" // Upgraded with strict internal chronological sorting safeguards

#ifndef STOCHASTIC_ADAPTIVE_ON_DMI_CALCULATOR_MQH
#define STOCHASTIC_ADAPTIVE_ON_DMI_CALCULATOR_MQH

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
//| PURPOSE: Calculates an adaptive stochastic oscillator based on   |
//|          DMI output, ensuring O(1) incremental performance.      |
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

   // Mathematical Engines (Stateful for O(1) recursion)
   CDMIEngine        *m_dmi_engine;
   CMovingAverageCalculator m_slowing_engine;
   CMovingAverageCalculator m_signal_engine;

   // Persistent Buffers for internal states
   double            m_pDI[], m_nDI[];
   double            m_dmi_osc[];    // DMI Oscillator Data
   double            m_er_buffer[];  // Efficiency Ratio of DMI
   double            m_nsp_buffer[]; // Dynamic Stochastic Period (Lookback)
   double            m_raw_k[];      // Raw Adaptive %K

   // Factory Method for Engine instantiation
   virtual void      CreateDMIEngine();

public:
                     CStochAdaptiveOnDMICalculator();
   virtual          ~CStochAdaptiveOnDMICalculator();

   bool              Init(double gamma, int dmi_p, ENUM_DMI_OSC_TYPE osc_type, int er_p, int min_p, int max_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma);

   // CRITICAL: Calculates state incrementally based on prev_calculated
   void              Calculate(int rates_total, int prev_calculated,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               double &out_k[], double &out_d[]);
  };

//+------------------------------------------------------------------+
//| Constructor & Destructor                                         |
//+------------------------------------------------------------------+
CStochAdaptiveOnDMICalculator::CStochAdaptiveOnDMICalculator() : m_dmi_engine(NULL) {}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStochAdaptiveOnDMICalculator::~CStochAdaptiveOnDMICalculator()
  {
   if(CheckPointer(m_dmi_engine) != POINTER_INVALID)
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
//| Initialization phase                                             |
//+------------------------------------------------------------------+
bool CStochAdaptiveOnDMICalculator::Init(double gamma, int dmi_p, ENUM_DMI_OSC_TYPE osc_type, int er_p, int min_p, int max_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma)
  {
   m_dmi_p       = dmi_p;
   m_osc_type    = osc_type;
   m_er_p        = er_p;
   m_min_stoch_p = min_p;
   m_max_stoch_p = max_p;

   CreateDMIEngine();

   if(CheckPointer(m_dmi_engine) == POINTER_INVALID || !m_dmi_engine.Init(m_dmi_p))
      return false;
   if(!m_slowing_engine.Init(slow_p, slow_ma))
      return false;
   if(!m_signal_engine.Init(d_p, d_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (O(1) Engine)                                   |
//+------------------------------------------------------------------+
void CStochAdaptiveOnDMICalculator::Calculate(int rates_total, int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &out_k[], double &out_d[])
  {
   if(rates_total < m_dmi_p + m_er_p + m_max_stoch_p)
      return;

   if(CheckPointer(m_dmi_engine) == POINTER_INVALID)
      return;

// O(1) Pointer
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// 1. Dynamic Buffer Resizing and chronological sorting safety kényszerítés
   if(ArraySize(m_pDI) != rates_total)
     {
      ArrayResize(m_pDI, rates_total);
      ArrayResize(m_nDI, rates_total);
      ArrayResize(m_dmi_osc, rates_total);
      ArrayResize(m_er_buffer, rates_total);
      ArrayResize(m_nsp_buffer, rates_total);
      ArrayResize(m_raw_k, rates_total);

      ArraySetAsSeries(m_pDI, false);
      ArraySetAsSeries(m_nDI, false);
      ArraySetAsSeries(m_dmi_osc, false);
      ArraySetAsSeries(m_er_buffer, false);
      ArraySetAsSeries(m_nsp_buffer, false);
      ArraySetAsSeries(m_raw_k, false);
     }

// 2. Base DMI Calculation via encapsulated Engine
   m_dmi_engine.Calculate(rates_total, prev_calculated, open, high, low, close, m_pDI, m_nDI);

// 3. DMI Oscillator Line
   int loop_start_dmi = MathMax(m_dmi_p, start_index);
   for(int i = loop_start_dmi; i < rates_total; i++)
     {
      if(m_osc_type == OSC_PDI_MINUS_NDI)
         m_dmi_osc[i] = m_pDI[i] - m_nDI[i];
      else
         m_dmi_osc[i] = m_nDI[i] - m_pDI[i];
     }

// 4. Efficiency Ratio (ER) based strictly on DMI volatility
   int loop_start_er = MathMax(m_dmi_p + m_er_p, start_index);
   for(int i = loop_start_er; i < rates_total; i++)
     {
      double direction = MathAbs(m_dmi_osc[i] - m_dmi_osc[i - m_er_p]);
      double volatility = 0;
      for(int j = 0; j < m_er_p; j++)
         volatility += MathAbs(m_dmi_osc[i - j] - m_dmi_osc[i - j - 1]);

      m_er_buffer[i] = (volatility > 1.0e-9) ? direction / volatility : 0.0;
     }

// 5. Adaptive Period (NSP) Calculation (THE WINNING LOGIC)
// Inverse logic: High ER (Trend) = Short Period; Low ER (Chop) = Long Period
   for(int i = loop_start_er; i < rates_total; i++)
     {
      // Using MathRound for accuracy instead of rough casting
      m_nsp_buffer[i] = MathRound(m_min_stoch_p + (1.0 - m_er_buffer[i]) * (m_max_stoch_p - m_min_stoch_p));

      // Safety Limit: Stochastic mathematically breaks if period < 2 (Div by Zero)
      if(m_nsp_buffer[i] < 2)
         m_nsp_buffer[i] = 2;
     }

// 6. Raw %K on DMI Oscillator using dynamic lookback (NSP)
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
            break; // Safety
         if(m_dmi_osc[i-k] > highest)
            highest = m_dmi_osc[i-k];
         if(m_dmi_osc[i-k] < lowest)
            lowest = m_dmi_osc[i-k];
        }

      double range = highest - lowest;
      if(range > 1.0e-9)
         m_raw_k[i] = 100.0 * (m_dmi_osc[i] - lowest) / range;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i-1] : 50.0; // Flatline prevention fallback
     }

// 7. Final Smoothing (Engine handles O(1) internally)
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, out_k, stoch_start);

   int d_offset = stoch_start + m_slowing_engine.GetPeriod() - 1;
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, out_k, out_d, d_offset);
  }

//+==================================================================+
//| CLASS: CStochAdaptiveOnDMICalculator_HA (Heikin Ashi Support)    |
//+==================================================================+
class CStochAdaptiveOnDMICalculator_HA : public CStochAdaptiveOnDMICalculator
  {
protected:
   virtual void      CreateDMIEngine() override
     {
      // Injects the HA version of the DMI engine (Polymorphism)
      m_dmi_engine = new CDMIEngine_HA();
     }
  };
//+------------------------------------------------------------------+
#endif // STOCHASTIC_ADAPTIVE_ON_DMI_CALCULATOR_MQH