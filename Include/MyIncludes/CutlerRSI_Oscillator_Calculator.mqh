//+------------------------------------------------------------------+
//|                                 CutlerRSI_Oscillator_Calculator.mqh|
//|  Wrapper for the CutlerRSI_Engine to produce Oscillator output.  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\CutlerRSI_Calculator.mqh>

//+==================================================================+
//|           CLASS: CCutlerRSI_OscillatorCalculator                 |
//+==================================================================+
class CCutlerRSI_OscillatorCalculator
  {
protected:
   //--- Composition: Use the main CutlerRSI Calculator
   CCutlerRSICalculator *m_rsi_engine;

   //--- Persistent Buffers for Incremental Calculation
   double            m_rsi_buffer[];
   double            m_signal_buffer[];

   int               m_rsi_period;
   int               m_ma_period;

public:
                     CCutlerRSI_OscillatorCalculator(void);
   virtual          ~CCutlerRSI_OscillatorCalculator(void);

   //--- Init now takes ENUM_MA_TYPE and HA flag
   bool              Init(int rsi_p, int ma_p, ENUM_MA_TYPE ma_m, bool use_ha);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &osc_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CCutlerRSI_OscillatorCalculator::CCutlerRSI_OscillatorCalculator(void) : m_rsi_engine(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CCutlerRSI_OscillatorCalculator::~CCutlerRSI_OscillatorCalculator(void)
  {
   if(CheckPointer(m_rsi_engine) != POINTER_INVALID)
      delete m_rsi_engine;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CCutlerRSI_OscillatorCalculator::Init(int rsi_p, int ma_p, ENUM_MA_TYPE ma_m, bool use_ha)
  {
   m_rsi_period = rsi_p;
   m_ma_period  = ma_p;

// Instantiate correct engine
   if(use_ha)
      m_rsi_engine = new CCutlerRSICalculator_HA();
   else
      m_rsi_engine = new CCutlerRSICalculator();

// Initialize engine
   return m_rsi_engine.Init(rsi_p, ma_p, ma_m);
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CCutlerRSI_OscillatorCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &osc_buffer[])
  {
   if(CheckPointer(m_rsi_engine) == POINTER_INVALID)
      return;

// Resize internal buffers
   if(ArraySize(m_rsi_buffer) != rates_total)
     {
      ArrayResize(m_rsi_buffer, rates_total);
      ArrayResize(m_signal_buffer, rates_total);
     }

// Calculate RSI and Signal (Incremental)
// The RSI engine handles its own incremental logic
   m_rsi_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_rsi_buffer, m_signal_buffer);

// Calculate Oscillator (RSI - Signal)
// Valid from: RSI Period + MA Period - 1
   int start_pos = m_rsi_period + m_ma_period - 1;

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int loop_start = MathMax(start_pos, start_index);

   if(prev_calculated == 0)
      ArrayInitialize(osc_buffer, 0.0);

   for(int i = loop_start; i < rates_total; i++)
     {
      osc_buffer[i] = m_rsi_buffer[i] - m_signal_buffer[i];
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
