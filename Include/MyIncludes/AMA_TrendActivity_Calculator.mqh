//+------------------------------------------------------------------+
//|                                 AMA_TrendActivity_Calculator.mqh |
//|      VERSION 3.00: Refactored to use Composition Pattern.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

//--- Include the base calculators
#include <MyIncludes\AMA_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>

//+==================================================================+
//|             CLASS: CActivityCalculator                           |
//|  Uses composition to leverage existing AMA and ATR engines.      |
//+==================================================================+
class CActivityCalculator
  {
protected:
   //--- Sub-Calculators
   CAMACalculator      *m_ama_calc;
   CATRCalculator      *m_atr_calc;

   //--- Parameters
   int                  m_ama_period;
   int                  m_atr_period;
   int                  m_smoothing_period;
   double               m_pi_div_2;

   //--- Intermediate Buffers (Must persist state for incremental calc)
   double               m_buffer_ama[];
   double               m_buffer_atr[];
   double               m_scaled_activity[];

public:
                     CActivityCalculator(void);
                    ~CActivityCalculator(void);

   //--- Init now takes a flag for Heikin Ashi to instantiate correct sub-calcs
   bool                 Init(int ama_p, int fast_p, int slow_p, int atr_p, int smooth_p, bool use_ha);

   void                 Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &activity_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CActivityCalculator::CActivityCalculator(void) : m_ama_calc(NULL), m_atr_calc(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CActivityCalculator::~CActivityCalculator(void)
  {
   if(CheckPointer(m_ama_calc) != POINTER_INVALID)
      delete m_ama_calc;
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
      delete m_atr_calc;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CActivityCalculator::Init(int ama_p, int fast_p, int slow_p, int atr_p, int smooth_p, bool use_ha)
  {
   m_ama_period       = (ama_p < 1) ? 1 : ama_p;
   m_atr_period       = (atr_p < 1) ? 1 : atr_p;
   m_smoothing_period = (smooth_p < 1) ? 1 : smooth_p;
   m_pi_div_2         = M_PI / 2.0;

//--- Instantiate Sub-Calculators based on HA flag
   if(use_ha)
     {
      m_ama_calc = new CAMACalculator_HA();
      m_atr_calc = new CATRCalculator_HA();
     }
   else
     {
      m_ama_calc = new CAMACalculator();
      m_atr_calc = new CATRCalculator(); // Standard ATR
     }

//--- Initialize Sub-Calculators
   if(!m_ama_calc.Init(ama_p, fast_p, slow_p))
      return false;
   if(!m_atr_calc.Init(atr_p, ATR_POINTS))
      return false; // ATR in points needed for normalization

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CActivityCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &activity_buffer[])
  {
   int start_pos = m_ama_period + m_atr_period + m_smoothing_period;
   if(rates_total <= start_pos)
      return;

//--- 1. Resize Intermediate Buffers
   if(ArraySize(m_buffer_ama) != rates_total)
     {
      ArrayResize(m_buffer_ama, rates_total);
      ArrayResize(m_buffer_atr, rates_total);
      ArrayResize(m_scaled_activity, rates_total);
     }

//--- 2. Delegate to Sub-Calculators (They handle incremental logic internally)
   m_ama_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_buffer_ama);
// The standard CATRCalculator::Calculate signature is:
// Calculate(int rates_total, int prev_calculated, open, high, low, close, atr_buffer)
   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_buffer_atr);

//--- 3. Determine Start Index for Activity Calculation
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 4. Calculate Raw Activity and Scale (Incremental)
// We can start calculating activity as soon as we have valid AMA and ATR values.
// AMA valid from: m_ama_period
// ATR valid from: m_atr_period
   int loop_start_act = MathMax(MathMax(m_ama_period, m_atr_period) + 1, start_index);

   for(int i = loop_start_act; i < rates_total; i++)
     {
      if(m_buffer_atr[i] > 0)
        {
         // Activity = Change in AMA / Volatility (ATR)
         double raw_activity = MathAbs(m_buffer_ama[i] - m_buffer_ama[i-1]) / m_buffer_atr[i];

         // Normalize using Arctan to get a bounded oscillator (0 to 1 range usually, here scaled by pi/2)
         m_scaled_activity[i] = MathArctan(raw_activity) / m_pi_div_2;
        }
      else
        {
         m_scaled_activity[i] = 0;
        }
     }

//--- 5. Calculate Final SMA Smoothing (Incremental)
   int final_start_pos = MathMax(m_ama_period, m_atr_period) + m_smoothing_period;
   int loop_start_final = MathMax(final_start_pos, start_index);

   for(int i = loop_start_final; i < rates_total; i++)
     {
      double sum = 0;
      for(int j = 0; j < m_smoothing_period; j++)
         sum += m_scaled_activity[i-j];

      activity_buffer[i] = sum / m_smoothing_period;
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
