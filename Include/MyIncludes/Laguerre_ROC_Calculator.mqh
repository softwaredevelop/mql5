//+------------------------------------------------------------------+
//|                                      Laguerre_ROC_Calculator.mqh |
//|      Laguerre Rate of Change (Slope) Calculator.                 |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\Laguerre_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Enum for ROC Calculation Mode
enum ENUM_ROC_MODE
  {
   ROC_POINTS,   // Absolute difference (Slope)
   ROC_PERCENT   // Percentage change
  };

//+==================================================================+
//|           CLASS 1: CLaguerreROCCalculator (Base)                 |
//+==================================================================+
class CLaguerreROCCalculator
  {
protected:
   //--- Composition
   CLaguerreEngine          *m_laguerre_engine;
   CMovingAverageCalculator *m_signal_engine;

   //--- Internal Buffer for Laguerre Filter values
   double            m_filter_buffer[];

   virtual void      CreateEngines(void);

public:
                     CLaguerreROCCalculator(void);
   virtual          ~CLaguerreROCCalculator(void);

   bool              Init(double gamma, int signal_period, ENUM_MA_TYPE signal_method);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               ENUM_ROC_MODE roc_mode, double &roc_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreROCCalculator::CLaguerreROCCalculator(void)
  {
   m_laguerre_engine = NULL;
   m_signal_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreROCCalculator::~CLaguerreROCCalculator(void)
  {
   if(CheckPointer(m_laguerre_engine) != POINTER_INVALID)
      delete m_laguerre_engine;
   if(CheckPointer(m_signal_engine) != POINTER_INVALID)
      delete m_signal_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CLaguerreROCCalculator::CreateEngines(void)
  {
   m_laguerre_engine = new CLaguerreEngine();
   m_signal_engine = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreROCCalculator::Init(double gamma, int signal_period, ENUM_MA_TYPE signal_method)
  {
   CreateEngines();

   if(CheckPointer(m_laguerre_engine) == POINTER_INVALID || !m_laguerre_engine.Init(gamma, SOURCE_PRICE))
      return false;

   if(!m_signal_engine.Init(signal_period, signal_method))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CLaguerreROCCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                       ENUM_ROC_MODE roc_mode, double &roc_buffer[], double &signal_buffer[])
  {
   if(rates_total < 2)
      return;

//--- Resize Internal Buffer
   if(ArraySize(m_filter_buffer) != rates_total)
      ArrayResize(m_filter_buffer, rates_total);

//--- 1. Calculate Laguerre Filter (The source for ROC)
   m_laguerre_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, m_filter_buffer);

//--- 2. Calculate ROC (Incremental Loop)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 1;
   if(start_index < 1)
      start_index = 1;

   for(int i = start_index; i < rates_total; i++)
     {
      double current = m_filter_buffer[i];
      double prev = m_filter_buffer[i-1];

      if(roc_mode == ROC_POINTS)
        {
         // Simple Slope: Current - Previous
         roc_buffer[i] = current - prev;
        }
      else // ROC_PERCENT
        {
         // Percentage Change: (Current - Previous) / Previous * 100
         if(prev != 0.0)
            roc_buffer[i] = ((current - prev) / prev) * 100.0;
         else
            roc_buffer[i] = 0.0;
        }
     }

//--- 3. Calculate Signal Line
// We pass roc_buffer as the source for the MA
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, roc_buffer, signal_buffer);
  }

//+==================================================================+
//|           CLASS 2: CLaguerreROCCalculator_HA                     |
//+==================================================================+
class CLaguerreROCCalculator_HA : public CLaguerreROCCalculator
  {
protected:
   virtual void      CreateEngines(void) override;
  };

//+------------------------------------------------------------------+
//| Factory Override                                                 |
//+------------------------------------------------------------------+
void CLaguerreROCCalculator_HA::CreateEngines(void)
  {
   m_laguerre_engine = new CLaguerreEngine_HA();
   m_signal_engine = new CMovingAverageCalculator();
  }
//+------------------------------------------------------------------+
