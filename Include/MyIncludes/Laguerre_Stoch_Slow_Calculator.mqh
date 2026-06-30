//+------------------------------------------------------------------+
//|                               Laguerre_Stoch_Slow_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.21" // Upgraded with strict internal chronological sorting safeguards

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
   //--- Composition
   CLaguerreEngine          *m_laguerre_engine;
   CMovingAverageCalculator m_slowing_engine; // For Raw %K -> Slow %K
   CMovingAverageCalculator m_signal_engine;  // For Slow %K -> Signal %D

   //--- Internal Buffers
   double            m_raw_k[]; // Intermediate buffer for Fast %K

   virtual void      CreateEngines(void);

public:
                     CLaguerreStochSlowCalculator(void);
   virtual          ~CLaguerreStochSlowCalculator(void);

   bool              Init(double gamma, int slowing_period, ENUM_MA_TYPE slowing_method, int signal_period, ENUM_MA_TYPE signal_method);

   //--- Standard Calculate (Without volume)
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &slow_k_buffer[], double &signal_d_buffer[]);

   //--- Overloaded Calculate (With volume to support VWMA Slowing/Signal)
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &volume[],
                               double &slow_k_buffer[], double &signal_d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreStochSlowCalculator::CLaguerreStochSlowCalculator(void)
  {
   m_laguerre_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreStochSlowCalculator::~CLaguerreStochSlowCalculator(void)
  {
   if(CheckPointer(m_laguerre_engine) != POINTER_INVALID)
      delete m_laguerre_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CLaguerreStochSlowCalculator::CreateEngines(void)
  {
   m_laguerre_engine = new CLaguerreEngine();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreStochSlowCalculator::Init(double gamma, int slowing_period, ENUM_MA_TYPE slowing_method, int signal_period, ENUM_MA_TYPE signal_method)
  {
   CreateEngines();

   if(CheckPointer(m_laguerre_engine) == POINTER_INVALID || !m_laguerre_engine.Init(gamma, SOURCE_PRICE))
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
void CLaguerreStochSlowCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &slow_k_buffer[], double &signal_d_buffer[])
  {
   if(rates_total < 2)
      return;

   if(CheckPointer(m_laguerre_engine) == POINTER_INVALID)
      return;

//--- Resize Internal Buffer
   if(ArraySize(m_raw_k) != rates_total)
     {
      ArrayResize(m_raw_k, rates_total);
      ArraySetAsSeries(m_raw_k, false); // Fixed: strict chronological array safety on local buffers
     }

//--- 1. Calculate Laguerre Components
   double dummy_filt[];
   m_laguerre_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, dummy_filt);

//--- 2. Retrieve L0..L3 buffers
   double L0[], L1[], L2[], L3[];
   m_laguerre_engine.GetLBuffers(L0, L1, L2, L3);

//--- 3. Calculate Raw %K (Incremental Loop)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start_index; i < rates_total; i++)
     {
      double hh = MathMax(MathMax(L0[i], L1[i]), MathMax(L2[i], L3[i]));
      double ll = MathMin(MathMin(L0[i], L1[i]), MathMin(L2[i], L3[i]));

      double diff = hh - ll;

      if(diff > 0)
         m_raw_k[i] = ((L0[i] - ll) / diff) * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i-1] : 50.0;
     }

//--- 4. Calculate Slow %K (Smoothing Raw %K)
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, slow_k_buffer);

//--- 5. Calculate Signal %D (Smoothing Slow %K)
   int signal_offset = m_slowing_engine.GetPeriod();
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, slow_k_buffer, signal_d_buffer, signal_offset);
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Volume for VWMA)                    |
//+------------------------------------------------------------------+
void CLaguerreStochSlowCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      const long &volume[],
      double &slow_k_buffer[], double &signal_d_buffer[])
  {
   if(rates_total < 2)
      return;

   if(CheckPointer(m_laguerre_engine) == POINTER_INVALID)
      return;

//--- Resize Internal Buffer
   if(ArraySize(m_raw_k) != rates_total)
     {
      ArrayResize(m_raw_k, rates_total);
      ArraySetAsSeries(m_raw_k, false); // Fixed: strict chronological array safety on local buffers
     }

//--- 1. Calculate Laguerre Components
   double dummy_filt[];
   m_laguerre_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, dummy_filt);

//--- 2. Retrieve L0..L3 buffers
   double L0[], L1[], L2[], L3[];
   m_laguerre_engine.GetLBuffers(L0, L1, L2, L3);

//--- 3. Calculate Raw %K (Incremental Loop)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start_index; i < rates_total; i++)
     {
      double hh = MathMax(MathMax(L0[i], L1[i]), MathMax(L2[i], L3[i]));
      double ll = MathMin(MathMin(L0[i], L1[i]), MathMin(L2[i], L3[i]));

      double diff = hh - ll;

      if(diff > 0)
         m_raw_k[i] = ((L0[i] - ll) / diff) * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i-1] : 50.0;
     }

//--- 4. Convert long volume to double to support VWMA Slowing & Signal
   double vol_double[];
   ArrayResize(vol_double, rates_total);
   ArraySetAsSeries(vol_double, false); // Fixed: strict chronological array safety on local buffers
   for(int j = start_index; j < rates_total; j++)
      vol_double[j] = (double)volume[j];

//--- 5. Calculate Slow %K (Smoothing Raw %K)
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, vol_double, slow_k_buffer);

//--- 6. Calculate Signal %D (Smoothing Slow %K)
   int signal_offset = m_slowing_engine.GetPeriod();
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, slow_k_buffer, vol_double, signal_d_buffer, signal_offset);
  }

//+==================================================================+
//|           CLASS 2: CLaguerreStochSlowCalculator_HA               |
//+==================================================================+
class CLaguerreStochSlowCalculator_HA : public CLaguerreStochSlowCalculator
  {
protected:
   virtual void      CreateEngines(void) override;
  };

//+------------------------------------------------------------------+
void CLaguerreStochSlowCalculator_HA::CreateEngines(void)
  {
   m_laguerre_engine = new CLaguerreEngine_HA();
  }

#endif // LAGUERRE_STOCH_SLOW_CALCULATOR_MQH
//+------------------------------------------------------------------+
