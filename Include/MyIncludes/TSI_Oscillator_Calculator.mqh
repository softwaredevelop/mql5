//+------------------------------------------------------------------+
//|                                      TSI_Oscillator_Calculator.mqh|
//|    Wrapper for the TSI Calculator to produce Oscillator output.  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\TSI_Calculator.mqh>

//+==================================================================+
//|           CLASS: CTSICalculatorOscillator                        |
//+==================================================================+
class CTSICalculatorOscillator
  {
protected:
   //--- Composition: Use the main TSI Calculator
   CTSICalculator    *m_tsi_engine;

   //--- Persistent Buffers for Incremental Calculation
   double            m_tsi_buffer[];
   double            m_signal_buffer[];

public:
                     CTSICalculatorOscillator(void);
   virtual          ~CTSICalculatorOscillator(void);

   //--- Init now takes all MA types and HA flag
   bool              Init(int slow_p, ENUM_MA_TYPE slow_ma, int fast_p, ENUM_MA_TYPE fast_ma, int signal_p, ENUM_MA_TYPE signal_ma, bool use_ha);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &osc_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTSICalculatorOscillator::CTSICalculatorOscillator(void) : m_tsi_engine(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTSICalculatorOscillator::~CTSICalculatorOscillator(void)
  {
   if(CheckPointer(m_tsi_engine) != POINTER_INVALID)
      delete m_tsi_engine;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CTSICalculatorOscillator::Init(int slow_p, ENUM_MA_TYPE slow_ma, int fast_p, ENUM_MA_TYPE fast_ma, int signal_p, ENUM_MA_TYPE signal_ma, bool use_ha)
  {
// Instantiate correct engine
   if(use_ha)
      m_tsi_engine = new CTSICalculator_HA(); // Ensure CTSICalculator_HA is visible from TSI_Calculator.mqh
   else
      m_tsi_engine = new CTSICalculator();

// Initialize engine
// Ensure the Init method signature matches exactly what is in TSI_Calculator.mqh
   return m_tsi_engine.Init(slow_p, slow_ma, fast_p, fast_ma, signal_p, signal_ma);
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CTSICalculatorOscillator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &osc_buffer[])
  {
   if(CheckPointer(m_tsi_engine) == POINTER_INVALID)
      return;

// Resize internal buffers
   if(ArraySize(m_tsi_buffer) != rates_total)
      ArrayResize(m_tsi_buffer, rates_total);
   if(ArraySize(m_signal_buffer) != rates_total)
      ArrayResize(m_signal_buffer, rates_total);

// Calculate TSI and Signal (Incremental)
// The TSI engine handles its own incremental logic
   m_tsi_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_tsi_buffer, m_signal_buffer);

// Calculate Oscillator (TSI - Signal)
// Valid from: Slow + Fast + Signal - 2 (approx)
   int start_pos = m_tsi_engine.GetPeriodSlow() + m_tsi_engine.GetPeriodFast() + m_tsi_engine.GetPeriodSignal() - 1;

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int loop_start = MathMax(start_pos, start_index);

   if(prev_calculated == 0)
      ArrayInitialize(osc_buffer, 0.0);

   for(int i = loop_start; i < rates_total; i++)
     {
      osc_buffer[i] = m_tsi_buffer[i] - m_signal_buffer[i];
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
