//+------------------------------------------------------------------+
//|                                       CCI_PercentB_Calculator.mqh|
//|      Calculation engine for Standard and Heikin Ashi CCI %B.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\CCI_Calculator.mqh>

//+==================================================================+
//|           CLASS: CCCI_PercentBCalculator                         |
//+==================================================================+
class CCCI_PercentBCalculator
  {
protected:
   //--- Composition: Use the main CCI Calculator
   CCCI_Calculator   *m_cci_engine;

   //--- Persistent Buffers for Incremental Calculation
   double            m_cci_buffer[];
   double            m_signal_buffer[];
   double            m_upper_buffer[];
   double            m_lower_buffer[];

   int               m_cci_period;
   int               m_ma_period;
   int               m_bands_period;

public:
                     CCCI_PercentBCalculator(void);
   virtual          ~CCCI_PercentBCalculator(void);

   //--- Init now takes ENUM_MA_TYPE and HA flag
   bool              Init(int cci_p, int ma_p, ENUM_MA_TYPE ma_m, int bands_p, double bands_dev, bool use_ha);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &percent_b_out[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CCCI_PercentBCalculator::CCCI_PercentBCalculator(void) : m_cci_engine(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CCCI_PercentBCalculator::~CCCI_PercentBCalculator(void)
  {
   if(CheckPointer(m_cci_engine) != POINTER_INVALID)
      delete m_cci_engine;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CCCI_PercentBCalculator::Init(int cci_p, int ma_p, ENUM_MA_TYPE ma_m, int bands_p, double bands_dev, bool use_ha)
  {
   m_cci_period   = cci_p;
   m_ma_period    = ma_p;
   m_bands_period = bands_p;

// Instantiate correct engine
   if(use_ha)
      m_cci_engine = new CCCI_Calculator_HA();
   else
      m_cci_engine = new CCCI_Calculator();

// Initialize engine
   return m_cci_engine.Init(cci_p, ma_p, ma_m, bands_p, bands_dev);
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CCCI_PercentBCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                        double &percent_b_out[])
  {
   if(CheckPointer(m_cci_engine) == POINTER_INVALID)
      return;

// Resize internal buffers
   if(ArraySize(m_cci_buffer) != rates_total)
     {
      ArrayResize(m_cci_buffer, rates_total);
      ArrayResize(m_signal_buffer, rates_total);
      ArrayResize(m_upper_buffer, rates_total);
      ArrayResize(m_lower_buffer, rates_total);
     }

// Calculate CCI, Signal and Bands (Incremental)
// The CCI engine handles its own incremental logic
   m_cci_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          m_cci_buffer, m_signal_buffer, m_upper_buffer, m_lower_buffer);

// Calculate %B
// Valid from: CCI Period + Bands Period - 2
   int start_pos = m_cci_period + m_bands_period - 2;

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int loop_start = MathMax(start_pos, start_index);

   if(prev_calculated == 0)
      ArrayInitialize(percent_b_out, 50.0); // Default to mid-point (50%)

   for(int i = loop_start; i < rates_total; i++)
     {
      double band_width = m_upper_buffer[i] - m_lower_buffer[i];

      if(band_width != 0)
        {
         // FIX: Multiply by 100 to get percentage (0..100 scale)
         percent_b_out[i] = ((m_cci_buffer[i] - m_lower_buffer[i]) / band_width) * 100.0;
        }
      else
        {
         percent_b_out[i] = 50.0; // Mid-point
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
