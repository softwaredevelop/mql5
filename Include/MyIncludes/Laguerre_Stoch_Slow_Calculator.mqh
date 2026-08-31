//+------------------------------------------------------------------+
//|                               Laguerre_Stoch_Slow_Calculator.mqh |
//|      Engine for John Ehlers' Laguerre Stochastic Slow Oscillator |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Leak-free pointer management, bounds protection & VWMA support

#ifndef LAGUERRE_STOCH_SLOW_CALCULATOR_MQH
#define LAGUERRE_STOCH_SLOW_CALCULATOR_MQH

#include <MyIncludes\Laguerre_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|           CLASS 1: CLaguerreStochSlowCalculator (Base)           |
//+==================================================================+
class CLaguerreStochSlowCalculator
  {
protected:
   //--- Composition Engines
   CLaguerreEngine          *m_laguerre_engine;
   CMovingAverageCalculator  m_slowing_engine; // For Raw %K -> Slow %K
   CMovingAverageCalculator  m_signal_engine;  // For Slow %K -> Signal %D

   double                    m_gamma;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;

   //--- Internal State Buffers
   double                    m_raw_k[];
   double                    m_dummy_filt[];
   double                    m_L0[], m_L1[], m_L2[], m_L3[];

   virtual void              CreateEngines(void);

public:
                     CLaguerreStochSlowCalculator(void);
   virtual                  ~CLaguerreStochSlowCalculator(void);

   //--- Enhanced Pro Init (6 Parameters)
   bool                      Init(const double gamma, const int slowing_period, const ENUM_MA_TYPE slowing_method,
                                  const int signal_period, const ENUM_MA_TYPE signal_method, const ENUM_APPLIED_PRICE_HA_ALL price_source);

   //--- Legacy Compatible Init (5 Parameters)
   bool                      Init(const double gamma, const int slowing_period, const ENUM_MA_TYPE slowing_method,
                                  const int signal_period, const ENUM_MA_TYPE signal_method)
     {
      return Init(gamma, slowing_period, slowing_method, signal_period, signal_method, PRICE_CLOSE_STD);
     }

   //--- Modern Unified Calculation Method (Without Volume)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &slow_k_buffer[], double &signal_d_buffer[]);

   //--- Modern Unified Calculation Method (With Volume for VWMA)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const long &volume[],
                                       double &slow_k_buffer[], double &signal_d_buffer[]);

   //--- Legacy Overload with price_type parameter (Without Volume)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const ENUM_APPLIED_PRICE price_type,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &slow_k_buffer[], double &signal_d_buffer[])
     {
      if(m_source_price >= PRICE_CLOSE_STD)
         m_source_price = (ENUM_APPLIED_PRICE_HA_ALL)price_type;

      Calculate(rates_total, prev_calculated, open, high, low, close, slow_k_buffer, signal_d_buffer);
     }

   //--- Legacy Overload with price_type parameter (With Volume)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const ENUM_APPLIED_PRICE price_type,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const long &volume[],
                                       double &slow_k_buffer[], double &signal_d_buffer[])
     {
      if(m_source_price >= PRICE_CLOSE_STD)
         m_source_price = (ENUM_APPLIED_PRICE_HA_ALL)price_type;

      Calculate(rates_total, prev_calculated, open, high, low, close, volume, slow_k_buffer, signal_d_buffer);
     }

   int                       GetRequiredWarmup(void) const { return m_slowing_engine.GetPeriod() + m_signal_engine.GetPeriod() + 4; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreStochSlowCalculator::CLaguerreStochSlowCalculator(void) : m_laguerre_engine(NULL),
   m_gamma(0.7),
   m_source_price(PRICE_CLOSE_STD)
  {
   ArraySetAsSeries(m_raw_k,      false);
   ArraySetAsSeries(m_dummy_filt, false);
   ArraySetAsSeries(m_L0,         false);
   ArraySetAsSeries(m_L1,         false);
   ArraySetAsSeries(m_L2,         false);
   ArraySetAsSeries(m_L3,         false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreStochSlowCalculator::~CLaguerreStochSlowCalculator(void)
  {
   if(CheckPointer(m_laguerre_engine) != POINTER_INVALID)
     {
      delete m_laguerre_engine;
      m_laguerre_engine = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Factory Method (Safe Leak-Free Instantiation)                    |
//+------------------------------------------------------------------+
void CLaguerreStochSlowCalculator::CreateEngines(void)
  {
   if(CheckPointer(m_laguerre_engine) != POINTER_INVALID)
     {
      delete m_laguerre_engine;
      m_laguerre_engine = NULL;
     }
   m_laguerre_engine = new CLaguerreEngine();
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CLaguerreStochSlowCalculator::Init(const double gamma, const int slowing_period, const ENUM_MA_TYPE slowing_method,
                                        const int signal_period, const ENUM_MA_TYPE signal_method, const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_gamma        = fmax(0.0, fmin(1.0, gamma));
   m_source_price = price_source;

   CreateEngines();
   if(CheckPointer(m_laguerre_engine) == POINTER_INVALID || !m_laguerre_engine.Init(m_gamma, SOURCE_PRICE, m_source_price))
      return false;

   if(!m_slowing_engine.Init(slowing_period, slowing_method))
      return false;

   if(!m_signal_engine.Init(signal_period, signal_method))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard - No Volume)                                 |
//+------------------------------------------------------------------+
void CLaguerreStochSlowCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &slow_k_buffer[], double &signal_d_buffer[])
  {
   if(rates_total < 4 || CheckPointer(m_laguerre_engine) == POINTER_INVALID)
      return;

// Safe allocation of destination arrays
   if(ArraySize(slow_k_buffer) != rates_total)
     {
      ArrayResize(slow_k_buffer, rates_total);
      ArraySetAsSeries(slow_k_buffer, false);
      ArrayInitialize(slow_k_buffer, EMPTY_VALUE);
     }
   if(ArraySize(signal_d_buffer) != rates_total)
     {
      ArrayResize(signal_d_buffer, rates_total);
      ArraySetAsSeries(signal_d_buffer, false);
      ArrayInitialize(signal_d_buffer, EMPTY_VALUE);
     }

// Resize Internal Buffers
   if(ArraySize(m_raw_k) != rates_total)
     {
      ArrayResize(m_raw_k, rates_total);
      ArraySetAsSeries(m_raw_k, false);
     }

// 1. Calculate Laguerre Components
   m_laguerre_engine.CalculateFilter(rates_total, prev_calculated, open, high, low, close, m_dummy_filt);

// 2. Retrieve L0..L3 state buffers
   m_laguerre_engine.GetLBuffers(m_L0, m_L1, m_L2, m_L3);

// 3. Calculate Raw %K (Incremental Loop)
   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : 0;

   if(prev_calculated == 0)
     {
      m_raw_k[0] = 50.0;
      start_index = 1;
     }

   for(int i = start_index; i < rates_total; i++)
     {
      double hh = MathMax(MathMax(m_L0[i], m_L1[i]), MathMax(m_L2[i], m_L3[i]));
      double ll = MathMin(MathMin(m_L0[i], m_L1[i]), MathMin(m_L2[i], m_L3[i]));

      double diff = hh - ll;

      if(diff > 1.0e-9)
         m_raw_k[i] = ((m_L0[i] - ll) / diff) * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i - 1] : 50.0;
     }

// 4. Calculate Slow %K (Smoothing Raw %K)
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, slow_k_buffer, 0);

// 5. Calculate Signal %D (Smoothing Slow %K)
   int signal_offset = m_slowing_engine.GetPeriod();
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, slow_k_buffer, signal_d_buffer, signal_offset);
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Volume for VWMA)                    |
//+------------------------------------------------------------------+
void CLaguerreStochSlowCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      const long &volume[],
      double &slow_k_buffer[], double &signal_d_buffer[])
  {
   if(rates_total < 4 || CheckPointer(m_laguerre_engine) == POINTER_INVALID)
      return;

// Safe allocation of destination arrays
   if(ArraySize(slow_k_buffer) != rates_total)
     {
      ArrayResize(slow_k_buffer, rates_total);
      ArraySetAsSeries(slow_k_buffer, false);
      ArrayInitialize(slow_k_buffer, EMPTY_VALUE);
     }
   if(ArraySize(signal_d_buffer) != rates_total)
     {
      ArrayResize(signal_d_buffer, rates_total);
      ArraySetAsSeries(signal_d_buffer, false);
      ArrayInitialize(signal_d_buffer, EMPTY_VALUE);
     }

   if(ArraySize(m_raw_k) != rates_total)
     {
      ArrayResize(m_raw_k, rates_total);
      ArraySetAsSeries(m_raw_k, false);
     }

// 1. Calculate Laguerre Components
   m_laguerre_engine.CalculateFilter(rates_total, prev_calculated, open, high, low, close, m_dummy_filt);

// 2. Retrieve L0..L3 state buffers
   m_laguerre_engine.GetLBuffers(m_L0, m_L1, m_L2, m_L3);

// 3. Calculate Raw %K
   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : 0;

   if(prev_calculated == 0)
     {
      m_raw_k[0] = 50.0;
      start_index = 1;
     }

   for(int i = start_index; i < rates_total; i++)
     {
      double hh = MathMax(MathMax(m_L0[i], m_L1[i]), MathMax(m_L2[i], m_L3[i]));
      double ll = MathMin(MathMin(m_L0[i], m_L1[i]), MathMin(m_L2[i], m_L3[i]));

      double diff = hh - ll;

      if(diff > 1.0e-9)
         m_raw_k[i] = ((m_L0[i] - ll) / diff) * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i - 1] : 50.0;
     }

// 4. Convert volume to double array for VWMA support
   double vol_double[];
   ArrayResize(vol_double, rates_total);
   ArraySetAsSeries(vol_double, false);

   for(int j = start_index; j < rates_total; j++)
      vol_double[j] = (double)volume[j];

// 5. Calculate Slow %K (Smoothing Raw %K with Volume)
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, vol_double, slow_k_buffer, 0);

// 6. Calculate Signal %D (Smoothing Slow %K with Volume)
   int signal_offset = m_slowing_engine.GetPeriod();
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, slow_k_buffer, vol_double, signal_d_buffer, signal_offset);
  }

//+==================================================================+
//|           CLASS 2: CLaguerreStochSlowCalculator_HA (Legacy)      |
//+==================================================================+
class CLaguerreStochSlowCalculator_HA : public CLaguerreStochSlowCalculator
  {
protected:
   virtual void      CreateEngines(void) override
     {
      if(CheckPointer(m_laguerre_engine) != POINTER_INVALID)
        {
         delete m_laguerre_engine;
         m_laguerre_engine = NULL;
        }
      m_laguerre_engine = new CLaguerreEngine_HA();
     }
  };

#endif // LAGUERRE_STOCH_SLOW_CALCULATOR_MQH
//+------------------------------------------------------------------+
