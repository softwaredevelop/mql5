//+------------------------------------------------------------------+
//|                                     DMIStochastic_Calculator.mqh |
//|      Engine for Barbara Star's DMI Stochastic Oscillator         |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.20" // Leak-free pointer management, bounds protection & VWMA support

#ifndef DMISTOCHASTIC_CALCULATOR_MQH
#define DMISTOCHASTIC_CALCULATOR_MQH

#include <MyIncludes\DMI_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

#ifndef ENUM_DMISTOCH_DEFINITIONS_DEFINED
#define ENUM_DMISTOCH_DEFINITIONS_DEFINED
#ifndef ENUM_CANDLE_SOURCE_DEFINED
#define ENUM_CANDLE_SOURCE_DEFINED
enum ENUM_CANDLE_SOURCE { CANDLE_STANDARD, CANDLE_HEIKIN_ASHI };
#endif
enum ENUM_DMI_OSC_TYPE  { OSC_PDI_MINUS_NDI, OSC_NDI_MINUS_PDI };
#endif

//+==================================================================+
//|           CLASS: CDMIStochasticCalculator                        |
//+==================================================================+
class CDMIStochasticCalculator
  {
protected:
   CDMIEngine               *m_dmi_engine;
   CMovingAverageCalculator  m_slow_k_engine;
   CMovingAverageCalculator  m_smooth_d_engine;

   int                       m_dmi_period;
   int                       m_fast_k_period;
   int                       m_slow_k_period;
   int                       m_smooth_period;
   ENUM_DMI_OSC_TYPE         m_osc_type;

   //--- Persistent State Buffers
   double                    m_pDI[], m_nDI[];
   double                    m_dmiOsc[], m_fastK[];

   virtual void              CreateEngine(void);

public:
                     CDMIStochasticCalculator(void);
   virtual                  ~CDMIStochasticCalculator(void);

   bool                      Init(const int dmi_p, const int fast_k, const int slow_k, const int smooth_p,
                                  const ENUM_MA_TYPE k_method, const ENUM_MA_TYPE d_method, const ENUM_DMI_OSC_TYPE osc_type);

   //--- Standard Calculate (Without Volume)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &k_buffer[], double &d_buffer[]);

   //--- Overloaded Calculate (With Volume to support VWMA Slowing/Signal)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const long &volume[],
                                       double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CDMIStochasticCalculator::CDMIStochasticCalculator(void) : m_dmi_engine(NULL),
   m_dmi_period(10),
   m_fast_k_period(10),
   m_slow_k_period(3),
   m_smooth_period(3),
   m_osc_type(OSC_PDI_MINUS_NDI)
  {
   ArraySetAsSeries(m_pDI,    false);
   ArraySetAsSeries(m_nDI,    false);
   ArraySetAsSeries(m_dmiOsc, false);
   ArraySetAsSeries(m_fastK,  false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CDMIStochasticCalculator::~CDMIStochasticCalculator(void)
  {
   if(CheckPointer(m_dmi_engine) != POINTER_INVALID)
     {
      delete m_dmi_engine;
      m_dmi_engine = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Factory Method (Safe Leak-Free Instantiation)                    |
//+------------------------------------------------------------------+
void CDMIStochasticCalculator::CreateEngine(void)
  {
   if(CheckPointer(m_dmi_engine) != POINTER_INVALID)
     {
      delete m_dmi_engine;
      m_dmi_engine = NULL;
     }
   m_dmi_engine = new CDMIEngine();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CDMIStochasticCalculator::Init(const int dmi_p, const int fast_k, const int slow_k, const int smooth_p,
                                    const ENUM_MA_TYPE k_method, const ENUM_MA_TYPE d_method, const ENUM_DMI_OSC_TYPE osc_type)
  {
   m_dmi_period    = (dmi_p < 1) ? 1 : dmi_p;
   m_fast_k_period = (fast_k < 1) ? 1 : fast_k;
   m_slow_k_period = (slow_k < 1) ? 1 : slow_k;
   m_smooth_period = (smooth_p < 1) ? 1 : smooth_p;
   m_osc_type      = osc_type;

   CreateEngine();
   if(CheckPointer(m_dmi_engine) == POINTER_INVALID || !m_dmi_engine.Init(m_dmi_period))
      return false;

   if(!m_slow_k_engine.Init(m_slow_k_period, k_method))
      return false;

   if(!m_smooth_d_engine.Init(m_smooth_period, d_method))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard - No Volume)                                 |
//+------------------------------------------------------------------+
void CDMIStochasticCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
   int warmup = m_dmi_period + m_fast_k_period;
   if(rates_total < warmup || CheckPointer(m_dmi_engine) == POINTER_INVALID)
      return;

// Safe allocation of output buffers
   if(ArraySize(k_buffer) != rates_total)
     {
      ArrayResize(k_buffer, rates_total);
      ArraySetAsSeries(k_buffer, false);
      ArrayInitialize(k_buffer, EMPTY_VALUE);
     }
   if(ArraySize(d_buffer) != rates_total)
     {
      ArrayResize(d_buffer, rates_total);
      ArraySetAsSeries(d_buffer, false);
      ArrayInitialize(d_buffer, EMPTY_VALUE);
     }

// Resize internal buffers
   if(ArraySize(m_pDI) != rates_total)
     {
      ArrayResize(m_pDI,    rates_total);
      ArrayResize(m_nDI,    rates_total);
      ArrayResize(m_dmiOsc, rates_total);
      ArrayResize(m_fastK,  rates_total);

      ArraySetAsSeries(m_pDI,    false);
      ArraySetAsSeries(m_nDI,    false);
      ArraySetAsSeries(m_dmiOsc, false);
      ArraySetAsSeries(m_fastK,  false);
     }

// 1. Calculate +DI and -DI values
   m_dmi_engine.Calculate(rates_total, prev_calculated, open, high, low, close, m_pDI, m_nDI);

// 2. Calculate DMI Oscillator & Fast %K
   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : 0;
   int loop_start  = MathMax(m_dmi_period, start_index);

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
      double lowest  = m_dmiOsc[i];
      for(int j = 1; j < m_fast_k_period; j++)
        {
         highest = MathMax(highest, m_dmiOsc[i - j]);
         lowest  = MathMin(lowest,  m_dmiOsc[i - j]);
        }

      double range = highest - lowest;
      m_fastK[i] = (range > 1.0e-9) ? ((m_dmiOsc[i] - lowest) / range) * 100.0 : 50.0;
     }

// 3. Smooth K and D (Without Volume)
   m_slow_k_engine.CalculateOnArray(rates_total, prev_calculated, m_fastK, k_buffer, fast_k_start);
   int d_start = fast_k_start + m_slow_k_period - 1;
   m_smooth_d_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, d_start);
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Volume for VWMA)                    |
//+------------------------------------------------------------------+
void CDMIStochasticCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      const long &volume[],
      double &k_buffer[], double &d_buffer[])
  {
   int warmup = m_dmi_period + m_fast_k_period;
   if(rates_total < warmup || CheckPointer(m_dmi_engine) == POINTER_INVALID)
      return;

// Safe allocation of output buffers
   if(ArraySize(k_buffer) != rates_total)
     {
      ArrayResize(k_buffer, rates_total);
      ArraySetAsSeries(k_buffer, false);
      ArrayInitialize(k_buffer, EMPTY_VALUE);
     }
   if(ArraySize(d_buffer) != rates_total)
     {
      ArrayResize(d_buffer, rates_total);
      ArraySetAsSeries(d_buffer, false);
      ArrayInitialize(d_buffer, EMPTY_VALUE);
     }

   if(ArraySize(m_pDI) != rates_total)
     {
      ArrayResize(m_pDI,    rates_total);
      ArrayResize(m_nDI,    rates_total);
      ArrayResize(m_dmiOsc, rates_total);
      ArrayResize(m_fastK,  rates_total);

      ArraySetAsSeries(m_pDI,    false);
      ArraySetAsSeries(m_nDI,    false);
      ArraySetAsSeries(m_dmiOsc, false);
      ArraySetAsSeries(m_fastK,  false);
     }

// 1. Calculate +DI and -DI values
   m_dmi_engine.Calculate(rates_total, prev_calculated, open, high, low, close, m_pDI, m_nDI);

// 2. Calculate DMI Oscillator & Fast %K
   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : 0;
   int loop_start  = MathMax(m_dmi_period, start_index);

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
      double lowest  = m_dmiOsc[i];
      for(int j = 1; j < m_fast_k_period; j++)
        {
         highest = MathMax(highest, m_dmiOsc[i - j]);
         lowest  = MathMin(lowest,  m_dmiOsc[i - j]);
        }

      double range = highest - lowest;
      m_fastK[i] = (range > 1.0e-9) ? ((m_dmiOsc[i] - lowest) / range) * 100.0 : 50.0;
     }

// 3. Convert volume to double array for VWMA support
   double vol_double[];
   ArrayResize(vol_double, rates_total);
   ArraySetAsSeries(vol_double, false);

   for(int j = start_index; j < rates_total; j++)
      vol_double[j] = (double)volume[j];

// 4. Smooth K and D (With Volume)
   m_slow_k_engine.CalculateOnArray(rates_total, prev_calculated, m_fastK, vol_double, k_buffer, fast_k_start);
   int d_start = fast_k_start + m_slow_k_period - 1;
   m_smooth_d_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, vol_double, d_buffer, d_start);
  }

//+==================================================================+
//|             CLASS 2: CDMIStochasticCalculator_HA (Heikin Ashi)   |
//+==================================================================+
class CDMIStochasticCalculator_HA : public CDMIStochasticCalculator
  {
protected:
   virtual void      CreateEngine(void) override
     {
      if(CheckPointer(m_dmi_engine) != POINTER_INVALID)
        {
         delete m_dmi_engine;
         m_dmi_engine = NULL;
        }
      m_dmi_engine = new CDMIEngine_HA();
     }
  };

#endif // DMISTOCHASTIC_CALCULATOR_MQH
//+------------------------------------------------------------------+
