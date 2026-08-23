//+------------------------------------------------------------------+
//|                                  KAMA_Acceleration_Calculator.mqh|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Performance optimized second derivative of KAMA
#property description "Calculator engine for analyzing the acceleration (2nd derivative) of KAMA."

#ifndef KAMA_ACCELERATION_CALCULATOR_MQH
#define KAMA_ACCELERATION_CALCULATOR_MQH

#include <MyIncludes\KAMA_Calculator.mqh>

//+==================================================================+
//|             CLASS: CKamaAccelerationCalculator                   |
//+==================================================================+
class CKamaAccelerationCalculator
  {
private:
   CKamaCalculator   m_kama_calc;
   double            m_kama_buffer[];
   int               m_er_period;

public:
                     CKamaAccelerationCalculator(void);
                    ~CKamaAccelerationCalculator(void) {};

   bool              Init(const int er_p, const int fast_p, const int slow_p, const ENUM_APPLIED_PRICE_HA_ALL source);
   void              Calculate(const int rates_total,
                               const int prev_calculated,
                               const double &open[],
                               const double &high[],
                               const double &low[],
                               const double &close[],
                               double &accel_buffer[],
                               double &color_buffer[],
                               const double threshold);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CKamaAccelerationCalculator::CKamaAccelerationCalculator(void) : m_er_period(10)
  {
   ArraySetAsSeries(m_kama_buffer, false);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CKamaAccelerationCalculator::Init(const int er_p, const int fast_p, const int slow_p, const ENUM_APPLIED_PRICE_HA_ALL source)
  {
   m_er_period = (er_p < 1) ? 1 : er_p;
   return m_kama_calc.Init(er_p, fast_p, slow_p, source);
  }

//+------------------------------------------------------------------+
//| Incremental Calculation of 2nd Derivative & Thermal Matrix       |
//+------------------------------------------------------------------+
void CKamaAccelerationCalculator::Calculate(const int rates_total,
      const int prev_calculated,
      const double &open[],
      const double &high[],
      const double &low[],
      const double &close[],
      double &accel_buffer[],
      double &color_buffer[],
      const double threshold)
  {
   if(rates_total <= m_er_period + 2)
      return;

// Resize persistent KAMA buffer
   if(ArraySize(m_kama_buffer) != rates_total)
     {
      ArrayResize(m_kama_buffer, rates_total);
      ArraySetAsSeries(m_kama_buffer, false);
     }

// 1. Calculate Underlying KAMA Values
   m_kama_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_kama_buffer);

// 2. Clean initial invalid bars on fresh calculation
   if(prev_calculated == 0)
     {
      for(int i = 0; i <= m_er_period + 1; i++)
        {
         accel_buffer[i] = 0.0;
         color_buffer[i] = 0.0; // Index 0: clrGray
        }
     }

   int start_index = (prev_calculated == 0) ? (m_er_period + 2) : (prev_calculated - 1);
   if(start_index <= m_er_period + 1)
      start_index = m_er_period + 2;

// 3. Acceleration Loop: Accel = KAMA[t] - 2*KAMA[t-1] + KAMA[t-2]
   for(int i = start_index; i < rates_total; i++)
     {
      if(m_kama_buffer[i] == EMPTY_VALUE || m_kama_buffer[i - 1] == EMPTY_VALUE || m_kama_buffer[i - 2] == EMPTY_VALUE)
        {
         accel_buffer[i] = 0.0;
         color_buffer[i] = 0.0;
         continue;
        }

      accel_buffer[i] = m_kama_buffer[i] - 2.0 * m_kama_buffer[i - 1] + m_kama_buffer[i - 2];

      double current_accel  = accel_buffer[i];
      double previous_accel = accel_buffer[i - 1];

      // 4. Symmetrical Thermal 5-Zone Momentum Matrix
      if(MathAbs(current_accel) <= threshold)
        {
         color_buffer[i] = 0.0; // Index 0: clrGray (Neutral / Low Energy Consolidation)
        }
      else
         if(current_accel > 0.0)
           {
            if(current_accel > previous_accel)
               color_buffer[i] = 1.0; // Index 1: clrDodgerBlue (Strong Bullish Acceleration)
            else
               color_buffer[i] = 2.0; // Index 2: clrLightSkyBlue (Weak Bullish Deceleration)
           }
         else // current_accel < 0.0
           {
            if(current_accel < previous_accel)
               color_buffer[i] = 3.0; // Index 3: clrCrimson (Strong Bearish Acceleration)
            else
               color_buffer[i] = 4.0; // Index 4: clrCoral (Weak Bearish Deceleration)
           }
     }
  }

#endif // KAMA_ACCELERATION_CALCULATOR_MQH
//+------------------------------------------------------------------+
