//+------------------------------------------------------------------+
//|                                  Laguerre_Filter_Calculator.mqh  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.20" // Memory-safe pointer lifecycle & bounds protection

#ifndef LAGUERRE_FILTER_CALCULATOR_MQH
#define LAGUERRE_FILTER_CALCULATOR_MQH

#include <MyIncludes\Laguerre_Engine.mqh>

//+==================================================================+
//|             CLASS 1: CLaguerreFilterCalculator                   |
//+==================================================================+
class CLaguerreFilterCalculator
  {
protected:
   CLaguerreEngine   *m_engine;

   virtual void      CreateEngine(void);

public:
                     CLaguerreFilterCalculator(void);
   virtual          ~CLaguerreFilterCalculator(void);

   //--- Enhanced Pro Init
   bool              Init(const double gamma, const ENUM_INPUT_SOURCE source_type, const ENUM_APPLIED_PRICE_HA_ALL price_source);

   //--- Legacy Compatible Init
   bool              Init(const double gamma, const ENUM_INPUT_SOURCE source_type)
     {
      return Init(gamma, source_type, PRICE_CLOSE_STD);
     }

   //--- Modern Unified Calculation Method
   void              Calculate(const int rates_total, const int prev_calculated,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               double &filter_buffer[], double &fir_buffer[]);

   //--- Legacy Overload with price_type parameter
   void              Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               double &filter_buffer[], double &fir_buffer[])
     {
      Calculate(rates_total, prev_calculated, open, high, low, close, filter_buffer, fir_buffer);
     }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreFilterCalculator::CLaguerreFilterCalculator(void) : m_engine(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreFilterCalculator::~CLaguerreFilterCalculator(void)
  {
   if(CheckPointer(m_engine) != POINTER_INVALID)
     {
      delete m_engine;
      m_engine = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CLaguerreFilterCalculator::CreateEngine(void)
  {
   if(CheckPointer(m_engine) != POINTER_INVALID)
     {
      delete m_engine;
      m_engine = NULL;
     }
   m_engine = new CLaguerreEngine();
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CLaguerreFilterCalculator::Init(const double gamma, const ENUM_INPUT_SOURCE source_type, const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   CreateEngine();
   if(CheckPointer(m_engine) == POINTER_INVALID)
      return false;

   return m_engine.Init(gamma, source_type, price_source);
  }

//+------------------------------------------------------------------+
//| Main Incremental Calculation Loop                                |
//+------------------------------------------------------------------+
void CLaguerreFilterCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &filter_buffer[], double &fir_buffer[])
  {
   if(rates_total < 2 || CheckPointer(m_engine) == POINTER_INVALID)
      return;

// Safe allocation of destination arrays
   if(ArraySize(filter_buffer) != rates_total)
     {
      ArrayResize(filter_buffer, rates_total);
      ArraySetAsSeries(filter_buffer, false);
      ArrayInitialize(filter_buffer, EMPTY_VALUE);
     }
   if(ArraySize(fir_buffer) != rates_total)
     {
      ArrayResize(fir_buffer, rates_total);
      ArraySetAsSeries(fir_buffer, false);
      ArrayInitialize(fir_buffer, EMPTY_VALUE);
     }

// 1. Calculate Core Laguerre Filter
   m_engine.CalculateFilter(rates_total, prev_calculated, open, high, low, close, filter_buffer);

// 2. Calculate 4-Point FIR Comparison Filter
   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : 0;
   if(start_index < 3)
      start_index = 3;

   if(prev_calculated == 0)
     {
      fir_buffer[0] = filter_buffer[0];
      fir_buffer[1] = filter_buffer[1];
      fir_buffer[2] = filter_buffer[2];
     }

   for(int i = start_index; i < rates_total; i++)
     {
      fir_buffer[i] = (m_engine.GetPrice(i) +
                       2.0 * m_engine.GetPrice(i - 1) +
                       2.0 * m_engine.GetPrice(i - 2) +
                       m_engine.GetPrice(i - 3)) / 6.0;
     }
  }

//+==================================================================+
//|             CLASS 2: CLaguerreFilterCalculator_HA (Legacy Wrapp) |
//+==================================================================+
class CLaguerreFilterCalculator_HA : public CLaguerreFilterCalculator
  {
protected:
   virtual void      CreateEngine(void) override
     {
      if(CheckPointer(m_engine) != POINTER_INVALID)
        {
         delete m_engine;
         m_engine = NULL;
        }
      m_engine = new CLaguerreEngine_HA();
     }
  };

#endif // LAGUERRE_FILTER_CALCULATOR_MQH
//+------------------------------------------------------------------+
