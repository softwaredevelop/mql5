//+------------------------------------------------------------------+
//|                               Laguerre_Stoch_Fast_Calculator.mqh |
//|      Laguerre Stochastic: Stoch calculation on L0-L3 components. |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\Laguerre_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|           CLASS 1: CLaguerreStochFastCalculator (Base)           |
//+==================================================================+
class CLaguerreStochFastCalculator
  {
protected:
   //--- Composition
   CLaguerreEngine          *m_laguerre_engine;
   CMovingAverageCalculator *m_signal_engine;

   virtual void      CreateEngines(void);

public:
                     CLaguerreStochFastCalculator(void);
   virtual          ~CLaguerreStochFastCalculator(void);

   bool              Init(double gamma, int signal_period, ENUM_MA_TYPE signal_method);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &stoch_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreStochFastCalculator::CLaguerreStochFastCalculator(void)
  {
   m_laguerre_engine = NULL;
   m_signal_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreStochFastCalculator::~CLaguerreStochFastCalculator(void)
  {
   if(CheckPointer(m_laguerre_engine) != POINTER_INVALID)
      delete m_laguerre_engine;
   if(CheckPointer(m_signal_engine) != POINTER_INVALID)
      delete m_signal_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CLaguerreStochFastCalculator::CreateEngines(void)
  {
   m_laguerre_engine = new CLaguerreEngine();
   m_signal_engine = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreStochFastCalculator::Init(double gamma, int signal_period, ENUM_MA_TYPE signal_method)
  {
   CreateEngines();

   if(CheckPointer(m_laguerre_engine) == POINTER_INVALID || !m_laguerre_engine.Init(gamma, SOURCE_PRICE))
      return false;

   if(CheckPointer(m_signal_engine) == POINTER_INVALID || !m_signal_engine.Init(signal_period, signal_method))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CLaguerreStochFastCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &stoch_buffer[], double &signal_buffer[])
  {
   if(rates_total < 2)
      return;

//--- 1. Calculate Laguerre Components
   double dummy_filt[];
   m_laguerre_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, dummy_filt);

//--- 2. Retrieve L0..L3 buffers
   double L0[], L1[], L2[], L3[];
   m_laguerre_engine.GetLBuffers(L0, L1, L2, L3);

//--- 3. Calculate Stochastic (Incremental Loop)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start_index; i < rates_total; i++)
     {
      // Find Highest High and Lowest Low among L0..L3
      double hh = MathMax(MathMax(L0[i], L1[i]), MathMax(L2[i], L3[i]));
      double ll = MathMin(MathMin(L0[i], L1[i]), MathMin(L2[i], L3[i]));

      double diff = hh - ll;

      if(diff > 0)
        {
         // Standard formula: (Current - Low) / (High - Low)
         // Here "Current" is typically L0 (the most responsive component)
         stoch_buffer[i] = ((L0[i] - ll) / diff) * 100.0;
        }
      else
        {
         // Flat market or initialization
         stoch_buffer[i] = (i > 0) ? stoch_buffer[i-1] : 50.0;
        }
     }

//--- 4. Calculate Signal Line
// We pass stoch_buffer as the source for the MA
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, stoch_buffer, signal_buffer);
  }

//+==================================================================+
//|           CLASS 2: CLaguerreStochFastCalculator_HA               |
//+==================================================================+
class CLaguerreStochFastCalculator_HA : public CLaguerreStochFastCalculator
  {
protected:
   virtual void      CreateEngines(void) override;
  };

//+------------------------------------------------------------------+
//| Factory Override                                                 |
//+------------------------------------------------------------------+
void CLaguerreStochFastCalculator_HA::CreateEngines(void)
  {
   m_laguerre_engine = new CLaguerreEngine_HA();
   m_signal_engine = new CMovingAverageCalculator();
  }
//+------------------------------------------------------------------+
