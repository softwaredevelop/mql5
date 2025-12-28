//+------------------------------------------------------------------+
//|                                     CCI_Oscillator_Calculator.mqh|
//|    Wrapper for the CCI Calculator to produce Oscillator output.  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\CCI_Calculator.mqh>

//+==================================================================+
//|           CLASS: CCCI_OscillatorCalculator                       |
//+==================================================================+
class CCCI_OscillatorCalculator
  {
protected:
   //--- Composition: Use the main CCI Calculator
   CCCI_Calculator   *m_cci_engine;

   //--- Persistent Buffers for Incremental Calculation
   double            m_cci_buffer[];
   double            m_signal_buffer[];
   double            m_upper_dummy[]; // Not used for oscillator
   double            m_lower_dummy[]; // Not used for oscillator

   int               m_cci_period;
   int               m_ma_period;

public:
                     CCCI_OscillatorCalculator(void);
   virtual          ~CCCI_OscillatorCalculator(void);

   //--- Init now takes ENUM_MA_TYPE and HA flag
   bool              Init(int cci_p, int ma_p, ENUM_MA_TYPE ma_m, bool use_ha);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &osc_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CCCI_OscillatorCalculator::CCCI_OscillatorCalculator(void) : m_cci_engine(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CCCI_OscillatorCalculator::~CCCI_OscillatorCalculator(void)
  {
   if(CheckPointer(m_cci_engine) != POINTER_INVALID)
      delete m_cci_engine;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CCCI_OscillatorCalculator::Init(int cci_p, int ma_p, ENUM_MA_TYPE ma_m, bool use_ha)
  {
   m_cci_period = cci_p;
   m_ma_period  = ma_p;

// Instantiate correct engine
   if(use_ha)
      m_cci_engine = new CCCI_Calculator_HA();
   else
      m_cci_engine = new CCCI_Calculator();

// Initialize engine (Bands params are dummy as we don't use them)
   return m_cci_engine.Init(cci_p, ma_p, ma_m, 14, 2.0);
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CCCI_OscillatorCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &osc_buffer[])
  {
   if(CheckPointer(m_cci_engine) == POINTER_INVALID)
      return;

// Resize internal buffers
   if(ArraySize(m_cci_buffer) != rates_total)
     {
      ArrayResize(m_cci_buffer, rates_total);
      ArrayResize(m_signal_buffer, rates_total);
      ArrayResize(m_upper_dummy, rates_total);
      ArrayResize(m_lower_dummy, rates_total);
     }

// Calculate CCI and Signal (Incremental)
// The CCI engine handles its own incremental logic
   m_cci_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          m_cci_buffer, m_signal_buffer, m_upper_dummy, m_lower_dummy);

// Calculate Oscillator (CCI - Signal)
// Valid from: CCI Period + MA Period - 2
   int start_pos = m_cci_period + m_ma_period - 2;

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int loop_start = MathMax(start_pos, start_index);

   if(prev_calculated == 0)
      ArrayInitialize(osc_buffer, 0.0);

   for(int i = loop_start; i < rates_total; i++)
     {
      osc_buffer[i] = m_cci_buffer[i] - m_signal_buffer[i];
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
