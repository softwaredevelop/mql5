//+------------------------------------------------------------------+
//|                          Laguerre_Adaptive_Acceleration_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Adaptive Acceleration Engine with 5-zone thermal states
#property description "Calculator engine for analyzing the acceleration (2nd derivative) of the Adaptive Laguerre Filter."

#ifndef LAGUERRE_ADAPTIVE_ACCELERATION_CALCULATOR_MQH
#define LAGUERRE_ADAPTIVE_ACCELERATION_CALCULATOR_MQH

#include <MyIncludes\Laguerre_Adaptive_Filter_Calculator.mqh>

//+==================================================================+
//|             CLASS: CLaguerreAdaptiveAccelerationCalculator       |
//+==================================================================+
class CLaguerreAdaptiveAccelerationCalculator
  {
private:
   CLaguerreAdaptiveFilterCalculator *m_filter_calc;
   double                             m_filter_buffer[];

public:
                     CLaguerreAdaptiveAccelerationCalculator(void);
                    ~CLaguerreAdaptiveAccelerationCalculator(void);

   bool              Init(ENUM_ADAPTIVE_METHOD method, int adaptive_period, double gamma_min, double gamma_max, bool is_ha);
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &accel_buffer[], double &color_buffer[], double threshold);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreAdaptiveAccelerationCalculator::CLaguerreAdaptiveAccelerationCalculator(void)
   : m_filter_calc(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreAdaptiveAccelerationCalculator::~CLaguerreAdaptiveAccelerationCalculator(void)
  {
   if(CheckPointer(m_filter_calc) != POINTER_INVALID)
      delete m_filter_calc;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreAdaptiveAccelerationCalculator::Init(ENUM_ADAPTIVE_METHOD method, int adaptive_period, double gamma_min, double gamma_max, bool is_ha)
  {
   if(CheckPointer(m_filter_calc) != POINTER_INVALID)
      delete m_filter_calc;

   m_filter_calc = new CLaguerreAdaptiveFilterCalculator();
   if(CheckPointer(m_filter_calc) == POINTER_INVALID)
      return false;

   return m_filter_calc.Init(method, adaptive_period, gamma_min, gamma_max, is_ha);
  }

//+------------------------------------------------------------------+
//| Calculate (2nd derivative of Adaptive Filter with thermal matrix) |
//+------------------------------------------------------------------+
void CLaguerreAdaptiveAccelerationCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &accel_buffer[], double &color_buffer[], double threshold)
  {
   if(CheckPointer(m_filter_calc) == POINTER_INVALID || rates_total < 5)
      return;

//--- Resize state buffers and force chronological alignment
   if(ArraySize(m_filter_buffer) != rates_total)
     {
      ArrayResize(m_filter_buffer, rates_total);
      ArraySetAsSeries(m_filter_buffer, false);
     }

//--- Calculate underlying Adaptive Filter
   m_filter_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_filter_buffer);

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

//--- Warm-up initialization for index 0 and 1
   if(start_index < 2)
     {
      accel_buffer[0] = 0.0;
      color_buffer[0] = 0.0;
      accel_buffer[1] = 0.0;
      color_buffer[1] = 0.0;
      start_index = 2;
     }

//--- Acceleration: Accel = Filter[t] - 2*Filter[t-1] + Filter[t-2]
   for(int i = start_index; i < rates_total; i++)
     {
      accel_buffer[i] = m_filter_buffer[i] - 2.0 * m_filter_buffer[i - 1] + m_filter_buffer[i - 2];

      double current_accel  = accel_buffer[i];
      double previous_accel = accel_buffer[i - 1];

      //--- Classify into 5-zone Symmetrical Thermal Acceleration Matrix
      if(MathAbs(current_accel) <= threshold)
        {
         color_buffer[i] = 0.0; // Index 0: clrGray (Neutral / Consolidation)
        }
      else
         if(current_accel > 0.0)
           {
            if(current_accel > previous_accel)
               color_buffer[i] = 1.0; // Index 1: clrDodgerBlue (Strong Bull Acceleration)
            else
               color_buffer[i] = 2.0; // Index 2: clrLightSkyBlue (Weak Bull Acceleration)
           }
         else // current_accel < 0.0
           {
            if(current_accel < previous_accel)
               color_buffer[i] = 3.0; // Index 3: clrCrimson (Strong Bear Acceleration)
            else
               color_buffer[i] = 4.0; // Index 4: clrCoral (Weak Bear Acceleration)
           }
     }
  }

#endif // LAGUERRE_ADAPTIVE_ACCELERATION_CALCULATOR_MQH
//+------------------------------------------------------------------+
