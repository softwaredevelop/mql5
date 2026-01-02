//+------------------------------------------------------------------+
//|                                               CMO_Calculator.mqh |
//|      VERSION 4.00: Wrapper using CMO_Engine + MA Engine.         |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\CMO_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|               CLASS 1: CCMOCalculator (Wrapper)                  |
//+==================================================================+
class CCMOCalculator
  {
protected:
   int               m_cmo_period;
   int               m_ma_period;
   double            m_deviation;

   //--- Composition: Core Engine + Signal Engine
   CCMOEngine        *m_cmo_engine;
   CMovingAverageCalculator m_ma_engine;

   //--- Persistent Buffers
   double            m_cmo_buffer[];
   double            m_ma_buffer[];

public:
                     CCMOCalculator(void);
   virtual          ~CCMOCalculator(void);

   bool              Init(int cmo_p, int ma_p, ENUM_MA_TYPE ma_m, double dev);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &cmo_out[], double &ma_out[], double &upper_out[], double &lower_out[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CCMOCalculator::CCMOCalculator(void) : m_cmo_engine(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CCMOCalculator::~CCMOCalculator(void)
  {
   if(CheckPointer(m_cmo_engine) != POINTER_INVALID)
      delete m_cmo_engine;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CCMOCalculator::Init(int cmo_p, int ma_p, ENUM_MA_TYPE ma_m, double dev)
  {
   m_cmo_period = cmo_p;
   m_ma_period  = ma_p;
   m_deviation  = dev;

// Instantiate base engine (Standard by default, HA handled by derived class)
// Wait, we need polymorphism here too!
// The wrapper itself needs to be polymorphic or handle the engine creation.
// Let's make this class concrete and instantiate the correct engine in Init?
// No, Init doesn't know about HA vs Std. The caller (OnInit) decides.

// Solution: The caller instantiates CCMOCalculator or CCMOCalculator_HA.
// The constructor of CCMOCalculator creates CCMOEngine.
// The constructor of CCMOCalculator_HA creates CCMOEngine_HA.

   if(CheckPointer(m_cmo_engine) == POINTER_INVALID)
      m_cmo_engine = new CCMOEngine(); // Default

   if(!m_cmo_engine.Init(m_cmo_period))
      return false;
   if(!m_ma_engine.Init(m_ma_period, ma_m))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CCMOCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &cmo_out[], double &ma_out[], double &upper_out[], double &lower_out[])
  {
   if(CheckPointer(m_cmo_engine) == POINTER_INVALID)
      return;

// Resize internal buffers
   if(ArraySize(m_cmo_buffer) != rates_total)
     {
      ArrayResize(m_cmo_buffer, rates_total);
      ArrayResize(m_ma_buffer, rates_total);
     }

//--- 1. Calculate CMO (Using Engine)
   m_cmo_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_cmo_buffer);

//--- 2. Calculate Signal Line (Using MA Engine)
   int cmo_offset = m_cmo_period;
   m_ma_engine.CalculateOnArray(rates_total, prev_calculated, m_cmo_buffer, m_ma_buffer, cmo_offset);

//--- 3. Calculate Bollinger Bands
   int ma_start_pos = cmo_offset + m_ma_period - 1;
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int loop_start = MathMax(ma_start_pos, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double std_dev_val = 0, sum_sq = 0;
      for(int j = 0; j < m_ma_period; j++)
         sum_sq += pow(m_cmo_buffer[i-j] - m_ma_buffer[i], 2);

      std_dev_val = sqrt(sum_sq / m_ma_period);

      // Copy to output buffers
      cmo_out[i] = m_cmo_buffer[i];
      ma_out[i] = m_ma_buffer[i];
      upper_out[i] = m_ma_buffer[i] + m_deviation * std_dev_val;
      lower_out[i] = m_ma_buffer[i] - m_deviation * std_dev_val;
     }
  }

//+==================================================================+
//|             CLASS 2: CCMOCalculator_HA (Wrapper)                 |
//+==================================================================+
class CCMOCalculator_HA : public CCMOCalculator
  {
public:
                     CCMOCalculator_HA(void);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CCMOCalculator_HA::CCMOCalculator_HA(void)
  {
   if(CheckPointer(m_cmo_engine) != POINTER_INVALID)
      delete m_cmo_engine;
// Use HA version of Engine
   m_cmo_engine = new CCMOEngine_HA();
  }
//+------------------------------------------------------------------+
