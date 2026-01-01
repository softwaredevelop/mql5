//+------------------------------------------------------------------+
//|                                     Holt_Oscillator_Calculator.mqh|
//|      Wrapper for the Holt_Engine to produce Oscillator output.   |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Holt_Engine.mqh>

//+==================================================================+
//|           CLASS: CHoltOscillatorCalculator                       |
//+==================================================================+
class CHoltOscillatorCalculator
  {
protected:
   //--- Composition: Use the main Holt Engine
   CHoltEngine       *m_engine;

   //--- Dummy Buffers for unused outputs
   double            m_dummy_forecast[];
   double            m_dummy_level[];
   double            m_dummy_upper[];
   double            m_dummy_lower[];

public:
                     CHoltOscillatorCalculator(void);
   virtual          ~CHoltOscillatorCalculator(void);

   //--- Init now takes HA flag
   bool              Init(int period, double alpha, double beta, bool use_ha);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &osc_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CHoltOscillatorCalculator::CHoltOscillatorCalculator(void) : m_engine(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CHoltOscillatorCalculator::~CHoltOscillatorCalculator(void)
  {
   if(CheckPointer(m_engine) != POINTER_INVALID)
      delete m_engine;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CHoltOscillatorCalculator::Init(int period, double alpha, double beta, bool use_ha)
  {
// Instantiate correct engine
   if(use_ha)
      m_engine = new CHoltEngine_HA();
   else
      m_engine = new CHoltEngine();

// Initialize engine (Forecast period is dummy 1)
   return m_engine.Init(period, alpha, beta, 1);
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CHoltOscillatorCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &osc_buffer[])
  {
   if(CheckPointer(m_engine) == POINTER_INVALID)
      return;

// Resize dummy buffers
   if(ArraySize(m_dummy_forecast) != rates_total)
     {
      ArrayResize(m_dummy_forecast, rates_total);
      ArrayResize(m_dummy_level, rates_total);
      ArrayResize(m_dummy_upper, rates_total);
      ArrayResize(m_dummy_lower, rates_total);
     }

// Calculate Holt (Incremental)
// The engine handles its own incremental logic
// We pass osc_buffer to the 'trend_out' parameter
   m_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                      m_dummy_forecast, osc_buffer, m_dummy_level, m_dummy_upper, m_dummy_lower);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
