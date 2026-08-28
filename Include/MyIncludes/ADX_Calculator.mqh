//+------------------------------------------------------------------+
//|                                               ADX_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.20" // Upgraded with leak-free pointer management and bounds protection

#ifndef ADX_CALCULATOR_MQH
#define ADX_CALCULATOR_MQH

#include <MyIncludes\DMI_Engine.mqh>

//+==================================================================+
//|             CLASS 1: CADXCalculator                             |
//+==================================================================+
class CADXCalculator
  {
protected:
   CDMIEngine        *m_dmi_engine;
   int               m_adx_period;
   double            m_dx[];

   virtual void      CreateEngine(void);

public:
                     CADXCalculator(void);
   virtual          ~CADXCalculator(void);

   bool              Init(const int period);
   int               GetPeriod(void) const { return m_adx_period; }

   void              Calculate(const int rates_total, const int prev_calculated,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               double &adx_buffer[], double &pdi_buffer[], double &ndi_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CADXCalculator::CADXCalculator(void) : m_dmi_engine(NULL), m_adx_period(14)
  {
   ArraySetAsSeries(m_dx, false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CADXCalculator::~CADXCalculator(void)
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
void CADXCalculator::CreateEngine(void)
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
bool CADXCalculator::Init(const int period)
  {
   m_adx_period = (period < 1) ? 1 : period;
   CreateEngine();
   if(CheckPointer(m_dmi_engine) == POINTER_INVALID)
      return false;

   return m_dmi_engine.Init(m_adx_period);
  }

//+------------------------------------------------------------------+
//| Main Incremental Calculation Loop                                |
//+------------------------------------------------------------------+
void CADXCalculator::Calculate(const int rates_total, const int prev_calculated,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               double &adx_buffer[], double &pdi_buffer[], double &ndi_buffer[])
  {
   if(rates_total < m_adx_period * 2 || CheckPointer(m_dmi_engine) == POINTER_INVALID)
      return;

// Safe allocation of destination array
   if(ArraySize(adx_buffer) != rates_total)
     {
      ArrayResize(adx_buffer, rates_total);
      ArraySetAsSeries(adx_buffer, false);
      ArrayInitialize(adx_buffer, EMPTY_VALUE);
     }

// Resize internal DX buffer
   if(ArraySize(m_dx) != rates_total)
     {
      ArrayResize(m_dx, rates_total);
      ArraySetAsSeries(m_dx, false);
     }

// 1. Calculate DI values using DMI Engine
   m_dmi_engine.Calculate(rates_total, prev_calculated, open, high, low, close, pdi_buffer, ndi_buffer);

// 2. Calculate DX
   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : 0;
   int loop_start  = MathMax(m_adx_period, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double di_sum = pdi_buffer[i] + ndi_buffer[i];
      if(di_sum > 1.0e-9)
         m_dx[i] = (MathAbs(pdi_buffer[i] - ndi_buffer[i]) / di_sum) * 100.0;
      else
         m_dx[i] = 0.0;
     }

// 3. Calculate ADX (Wilder's Smoothing on DX)
   int adx_start      = m_adx_period * 2 - 1;
   int loop_start_adx = MathMax(adx_start, start_index);

   for(int i = loop_start_adx; i < rates_total; i++)
     {
      if(i == adx_start)
        {
         double sum_dx = 0.0;
         for(int j = i - m_adx_period + 1; j <= i; j++)
            sum_dx += m_dx[j];
         adx_buffer[i] = sum_dx / (double)m_adx_period;
        }
      else
        {
         adx_buffer[i] = (adx_buffer[i - 1] * (double)(m_adx_period - 1) + m_dx[i]) / (double)m_adx_period;
        }
     }
  }

//+==================================================================+
//|             CLASS 2: CADXCalculator_HA (Heikin Ashi)             |
//+==================================================================+
class CADXCalculator_HA : public CADXCalculator
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

#endif // ADX_CALCULATOR_MQH
//+------------------------------------------------------------------+
