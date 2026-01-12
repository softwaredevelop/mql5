//+------------------------------------------------------------------+
//|                               Inverse_Fisher_RSI_Calculator.mqh  |
//|      VERSION 3.00: Refactored to use RSI_Engine.                 |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\RSI_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CInverseFisherRSICalculator
  {
protected:
   CRSIEngine        *m_rsi_engine;
   CMovingAverageCalculator m_wma_engine;

   int               m_rsi_period, m_wma_period;
   double            m_rsi_buffer[], m_value1[], m_value2[];

   virtual void      CreateRSIEngine(void);

public:
                     CInverseFisherRSICalculator(void);
   virtual          ~CInverseFisherRSICalculator(void);

   bool              Init(int rsi_period, int wma_period);
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &ifish_buffer[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CInverseFisherRSICalculator::CInverseFisherRSICalculator(void) { m_rsi_engine = NULL; }
CInverseFisherRSICalculator::~CInverseFisherRSICalculator(void) { if(CheckPointer(m_rsi_engine) != POINTER_INVALID) delete m_rsi_engine; }

void CInverseFisherRSICalculator::CreateRSIEngine(void) { m_rsi_engine = new CRSIEngine(); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CInverseFisherRSICalculator::Init(int rsi_period, int wma_period)
  {
   m_rsi_period = rsi_period;
   m_wma_period = wma_period;
   CreateRSIEngine();
   if(!m_rsi_engine.Init(m_rsi_period))
      return false;
   if(!m_wma_engine.Init(m_wma_period, LWMA))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CInverseFisherRSICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &ifish_buffer[])
  {
   if(rates_total <= m_rsi_period + m_wma_period)
      return;

   if(ArraySize(m_rsi_buffer) != rates_total)
     {
      ArrayResize(m_rsi_buffer, rates_total);
      ArrayResize(m_value1, rates_total);
      ArrayResize(m_value2, rates_total);
     }

// 1. Calculate RSI
   m_rsi_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_rsi_buffer);

// 2. Scale RSI
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int loop_start = MathMax(m_rsi_period, start_index);

   for(int i = loop_start; i < rates_total; i++)
      m_value1[i] = 0.1 * (m_rsi_buffer[i] - 50.0);

// 3. Smooth with WMA
   m_wma_engine.CalculateOnArray(rates_total, prev_calculated, m_value1, m_value2, m_rsi_period);

// 4. Inverse Fisher
   int loop_start_ifish = MathMax(m_rsi_period + m_wma_period - 1, start_index);
   for(int i = loop_start_ifish; i < rates_total; i++)
     {
      double x = m_value2[i];
      if(x > 10)
         x = 10;
      if(x < -10)
         x = -10;
      double exp2x = exp(2.0 * x);
      ifish_buffer[i] = (exp2x - 1.0) / (exp2x + 1.0);
     }
  }

//--- HA Subclass
class CInverseFisherRSICalculator_HA : public CInverseFisherRSICalculator
  {
protected:
   virtual void      CreateRSIEngine(void) override { m_rsi_engine = new CRSIEngine_HA(); }
  };
//+------------------------------------------------------------------+
