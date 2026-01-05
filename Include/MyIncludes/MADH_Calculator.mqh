//+------------------------------------------------------------------+
//|                                              MADH_Calculator.mqh |
//|      Calculation engine for the John Ehlers' MADH indicator.     |
//|      VERSION 3.10: Fixed pointer declaration bug.                |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Windowed_MA_Calculator.mqh>

//+==================================================================+
//|             CLASS 1: CMADHCalculator (Base Class)                |
//+==================================================================+
class CMADHCalculator
  {
protected:
   int               m_short_len;
   int               m_dom_cycle;

   //--- Engines (Pointers!)
   CWindowedMACalculator *m_short_ma;
   CWindowedMACalculator *m_long_ma;

   //--- Persistent Buffers for MA outputs
   double            m_short_buffer[];
   double            m_long_buffer[];

   //--- Factory Method for Engines
   virtual void      CreateEngines(void);

public:
                     CMADHCalculator(void);
   virtual          ~CMADHCalculator(void);

   bool              Init(int short_len, int dom_cycle);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &madh_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMADHCalculator::CMADHCalculator(void)
  {
   m_short_ma = NULL;
   m_long_ma = NULL;
// Note: CreateEngines is virtual, so calling it in constructor is risky in C++,
// but in MQL5 it calls the base version. We should call it in Init or handle it carefully.
// However, for simplicity here, we can call it, but the derived class constructor runs AFTER base.
// So the derived class will overwrite these pointers.
// Better pattern: Call CreateEngines in Init or check for NULL.
// But let's stick to the pattern used in other calculators:
// Base constructor creates base engines. Derived constructor deletes and creates derived engines.
   m_short_ma = new CWindowedMACalculator();
   m_long_ma = new CWindowedMACalculator();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMADHCalculator::~CMADHCalculator(void)
  {
   if(CheckPointer(m_short_ma) != POINTER_INVALID)
      delete m_short_ma;
   if(CheckPointer(m_long_ma) != POINTER_INVALID)
      delete m_long_ma;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CMADHCalculator::CreateEngines(void)
  {
// This method is actually not needed if we handle creation in constructors properly.
// But let's keep it for clarity if we want to re-init.
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMADHCalculator::Init(int short_len, int dom_cycle)
  {
   m_short_len = (short_len < 1) ? 1 : short_len;
   m_dom_cycle = (dom_cycle < 1) ? 1 : dom_cycle;

   int long_len = m_short_len + (int)round(m_dom_cycle / 2.0);

   if(CheckPointer(m_short_ma) == POINTER_INVALID || CheckPointer(m_long_ma) == POINTER_INVALID)
      return false;

// Initialize Engines (Hann Window, Price Source)
   if(!m_short_ma.Init(m_short_len, SOURCE_PRICE))
      return false;
   if(!m_long_ma.Init(long_len, SOURCE_PRICE))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CMADHCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &madh_buffer[])
  {
   int long_len = m_short_len + (int)round(m_dom_cycle / 2.0);
   if(rates_total < long_len)
      return;

// Resize internal buffers
   if(ArraySize(m_short_buffer) != rates_total)
     {
      ArrayResize(m_short_buffer, rates_total);
      ArrayResize(m_long_buffer, rates_total);
     }

// 1. Calculate Short MA (Delegated)
   m_short_ma.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_short_buffer);

// 2. Calculate Long MA (Delegated)
   m_long_ma.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_long_buffer);

// 3. Calculate MADH (Incremental Loop)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int loop_start = MathMax(long_len - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double filt1 = m_short_buffer[i];
      double filt2 = m_long_buffer[i];

      if(filt2 != 0 && filt2 != EMPTY_VALUE && filt1 != EMPTY_VALUE)
        {
         madh_buffer[i] = 100.0 * (filt1 - filt2) / filt2;
        }
      else
        {
         madh_buffer[i] = 0.0;
        }
     }
  }

//+==================================================================+
//|             CLASS 2: CMADHCalculator_HA (Heikin Ashi)            |
//+==================================================================+
class CMADHCalculator_HA : public CMADHCalculator
  {
public:
                     CMADHCalculator_HA(void);
  };

//+------------------------------------------------------------------+
//| Constructor (HA)                                                 |
//+------------------------------------------------------------------+
CMADHCalculator_HA::CMADHCalculator_HA(void)
  {
   if(CheckPointer(m_short_ma) != POINTER_INVALID)
      delete m_short_ma;
   if(CheckPointer(m_long_ma) != POINTER_INVALID)
      delete m_long_ma;

// Use HA Engines
   m_short_ma = new CWindowedMACalculator_HA();
   m_long_ma = new CWindowedMACalculator_HA();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
