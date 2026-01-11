//+------------------------------------------------------------------+
//|                                     DMIStochastic_Calculator.mqh |
//|      VERSION 3.00: Refactored to use DMI_Engine.                 |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\DMI_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

enum ENUM_CANDLE_SOURCE { CANDLE_STANDARD, CANDLE_HEIKIN_ASHI };
enum ENUM_DMI_OSC_TYPE { OSC_PDI_MINUS_NDI, OSC_NDI_MINUS_PDI };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CDMIStochasticCalculator
  {
protected:
   CDMIEngine        *m_dmi_engine;
   CMovingAverageCalculator m_slow_k_engine;
   CMovingAverageCalculator m_smooth_d_engine;

   int               m_dmi_period, m_fast_k_period, m_slow_k_period, m_smooth_period;
   ENUM_DMI_OSC_TYPE m_osc_type;

   //--- Internal Buffers
   double            m_pDI[], m_nDI[];
   double            m_dmiOsc[], m_fastK[];

   virtual void      CreateEngine(void);

public:
                     CDMIStochasticCalculator(void);
   virtual          ~CDMIStochasticCalculator(void);

   bool              Init(int dmi_p, int fast_k, int slow_k, int smooth_p, ENUM_MA_TYPE k_method, ENUM_MA_TYPE d_method, ENUM_DMI_OSC_TYPE osc_type);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CDMIStochasticCalculator::CDMIStochasticCalculator(void) { m_dmi_engine = NULL; }
CDMIStochasticCalculator::~CDMIStochasticCalculator(void) { if(CheckPointer(m_dmi_engine) != POINTER_INVALID) delete m_dmi_engine; }

void CDMIStochasticCalculator::CreateEngine(void) { m_dmi_engine = new CDMIEngine(); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CDMIStochasticCalculator::Init(int dmi_p, int fast_k, int slow_k, int smooth_p, ENUM_MA_TYPE k_method, ENUM_MA_TYPE d_method, ENUM_DMI_OSC_TYPE osc_type)
  {
   m_dmi_period = dmi_p;
   m_fast_k_period = fast_k;
   m_slow_k_period = slow_k;
   m_smooth_period = smooth_p;
   m_osc_type = osc_type;
   CreateEngine();
   if(!m_dmi_engine.Init(m_dmi_period))
      return false;
   if(!m_slow_k_engine.Init(m_slow_k_period, k_method))
      return false;
   if(!m_smooth_d_engine.Init(m_smooth_period, d_method))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CDMIStochasticCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
   if(rates_total < m_dmi_period + m_fast_k_period)
      return;

   if(ArraySize(m_pDI) != rates_total)
     {
      ArrayResize(m_pDI, rates_total);
      ArrayResize(m_nDI, rates_total);
      ArrayResize(m_dmiOsc, rates_total);
      ArrayResize(m_fastK, rates_total);
     }

// 1. Calculate DI values
   m_dmi_engine.Calculate(rates_total, prev_calculated, open, high, low, close, m_pDI, m_nDI);

// 2. Calculate DMI Oscillator & Fast %K
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int loop_start = MathMax(m_dmi_period, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      if(m_osc_type == OSC_PDI_MINUS_NDI)
         m_dmiOsc[i] = m_pDI[i] - m_nDI[i];
      else
         m_dmiOsc[i] = m_nDI[i] - m_pDI[i];
     }

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

// 3. Smooth K and D
   m_slow_k_engine.CalculateOnArray(rates_total, prev_calculated, m_fastK, k_buffer, fast_k_start);
   int d_start = fast_k_start + m_slow_k_period - 1;
   m_smooth_d_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, d_start);
  }

//--- HA Subclass
class CDMIStochasticCalculator_HA : public CDMIStochasticCalculator
  {
protected:
   virtual void      CreateEngine(void) override { m_dmi_engine = new CDMIEngine_HA(); }
  };
//+------------------------------------------------------------------+
