//+------------------------------------------------------------------+
//|                                      StochRSI_Fast_Calculator.mqh|
//|  VERSION 3.00: Refactored to use RSI_Engine.                     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\RSI_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|           CLASS: CStochRSI_Fast_Calculator                       |
//+==================================================================+
class CStochRSI_Fast_Calculator
  {
protected:
   int               m_rsi_period, m_k_period;

   //--- Composition: RSI Engine + MA Engine
   CRSIEngine        *m_rsi_engine;
   CMovingAverageCalculator m_ma_engine; // For %D smoothing

   //--- Persistent Buffers
   double            m_rsi_buffer[];

   //--- Factory Method for RSI Engine
   virtual void      CreateRSIEngine(void);

   double            Highest(const double &array[], int period, int current_pos);
   double            Lowest(const double &array[], int period, int current_pos);

public:
                     CStochRSI_Fast_Calculator(void);
   virtual          ~CStochRSI_Fast_Calculator(void);

   bool              Init(int rsi_p, int k_p, int d_p, ENUM_MA_TYPE d_ma);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStochRSI_Fast_Calculator::CStochRSI_Fast_Calculator(void)
  {
   m_rsi_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStochRSI_Fast_Calculator::~CStochRSI_Fast_Calculator(void)
  {
   if(CheckPointer(m_rsi_engine) != POINTER_INVALID)
      delete m_rsi_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CStochRSI_Fast_Calculator::CreateRSIEngine(void)
  {
   m_rsi_engine = new CRSIEngine();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochRSI_Fast_Calculator::Init(int rsi_p, int k_p, int d_p, ENUM_MA_TYPE d_ma)
  {
   m_rsi_period = (rsi_p < 1) ? 1 : rsi_p;
   m_k_period   = (k_p < 1) ? 1 : k_p;

   CreateRSIEngine();

   if(CheckPointer(m_rsi_engine) == POINTER_INVALID)
      return false;

   if(!m_rsi_engine.Init(m_rsi_period))
      return false;

   return m_ma_engine.Init(d_p, d_ma);
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CStochRSI_Fast_Calculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &k_buffer[], double &d_buffer[])
  {
   int min_bars = m_rsi_period + m_k_period + m_ma_engine.GetPeriod();
   if(rates_total <= min_bars)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_rsi_buffer) != rates_total)
      ArrayResize(m_rsi_buffer, rates_total);

//--- 1. Calculate RSI (Using Engine)
// The engine handles its own data preparation internally!
   m_rsi_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_rsi_buffer);

//--- 2. Calculate %K (StochRSI)
   int k_start_offset = m_rsi_period + m_k_period - 1;
   int loop_start_k = MathMax(k_start_offset, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      double highest_rsi = Highest(m_rsi_buffer, m_k_period, i);
      double lowest_rsi  = Lowest(m_rsi_buffer, m_k_period, i);
      double range = highest_rsi - lowest_rsi;

      if(range > 0.00001)
         k_buffer[i] = (m_rsi_buffer[i] - lowest_rsi) / range * 100.0;
      else
         k_buffer[i] = (i > 0) ? k_buffer[i-1] : 50.0;
     }

//--- 3. Calculate %D (Signal Line)
   m_ma_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, k_start_offset);
  }

//+------------------------------------------------------------------+
//| Highest                                                          |
//+------------------------------------------------------------------+
double CStochRSI_Fast_Calculator::Highest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res < array[index])
         res = array[index];
     }
   return(res);
  }

//+------------------------------------------------------------------+
//| Lowest                                                           |
//+------------------------------------------------------------------+
double CStochRSI_Fast_Calculator::Lowest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res > array[index])
         res = array[index];
     }
   return(res);
  }

//+==================================================================+
//|         CLASS 2: CStochRSI_Fast_Calculator_HA (Heikin Ashi)      |
//+==================================================================+
class CStochRSI_Fast_Calculator_HA : public CStochRSI_Fast_Calculator
  {
protected:
   virtual void      CreateRSIEngine(void) override;
  };

//+------------------------------------------------------------------+
//| Factory Method (Heikin Ashi)                                     |
//+------------------------------------------------------------------+
void CStochRSI_Fast_Calculator_HA::CreateRSIEngine(void)
  {
   m_rsi_engine = new CRSIEngine_HA();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
