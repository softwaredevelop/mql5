//+------------------------------------------------------------------+
//|                                         KAMA_Slope_Calculator.mqh|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Performance optimized first derivative of KAMA
#property description "Calculator engine for analyzing the slope (1st derivative) of KAMA."

#ifndef KAMA_SLOPE_CALCULATOR_MQH
#define KAMA_SLOPE_CALCULATOR_MQH

#include <MyIncludes\KAMA_Calculator.mqh>

//+==================================================================+
//|             CLASS: CKamaSlopeCalculator                          |
//+==================================================================+
class CKamaSlopeCalculator
  {
private:
   CKamaCalculator   m_kama_calc;
   double            m_kama_buffer[];
   int               m_er_period;

public:
                     CKamaSlopeCalculator(void);
                    ~CKamaSlopeCalculator(void) {};

   bool              Init(const int er_p, const int fast_p, const int slow_p, const ENUM_APPLIED_PRICE_HA_ALL source);
   void              Calculate(const int rates_total,
                               const int prev_calculated,
                               const double &open[],
                               const double &high[],
                               const double &low[],
                               const double &close[],
                               double &slope_buffer[],
                               double &color_buffer[],
                               const double threshold);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CKamaSlopeCalculator::CKamaSlopeCalculator(void) : m_er_period(10)
  {
   ArraySetAsSeries(m_kama_buffer, false);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CKamaSlopeCalculator::Init(const int er_p, const int fast_p, const int slow_p, const ENUM_APPLIED_PRICE_HA_ALL source)
  {
   m_er_period = (er_p < 1) ? 1 : er_p;
   return m_kama_calc.Init(er_p, fast_p, slow_p, source);
  }

//+------------------------------------------------------------------+
//| Incremental Calculation of KAMA Slope & 5-Zone Momentum Matrix   |
//+------------------------------------------------------------------+
void CKamaSlopeCalculator::Calculate(const int rates_total,
                                     const int prev_calculated,
                                     const double &open[],
                                     const double &high[],
                                     const double &low[],
                                     const double &close[],
                                     double &slope_buffer[],
                                     double &color_buffer[],
                                     const double threshold)
  {
   if(rates_total <= m_er_period + 1)
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
      for(int i = 0; i <= m_er_period; i++)
        {
         slope_buffer[i] = 0.0;
         color_buffer[i] = 0.0; // Index 0: clrGray
        }
     }

   int start_index = (prev_calculated == 0) ? (m_er_period + 1) : (prev_calculated - 1);
   if(start_index <= m_er_period)
      start_index = m_er_period + 1;

// 3. Slope Derivative Loop: Slope = KAMA[t] - KAMA[t-1]
   for(int i = start_index; i < rates_total; i++)
     {
      if(m_kama_buffer[i] == EMPTY_VALUE || m_kama_buffer[i - 1] == EMPTY_VALUE)
        {
         slope_buffer[i] = 0.0;
         color_buffer[i] = 0.0;
         continue;
        }

      slope_buffer[i] = m_kama_buffer[i] - m_kama_buffer[i - 1];

      double current_slope  = slope_buffer[i];
      double previous_slope = slope_buffer[i - 1];

      // 4. Symmetrical 5-Zone Momentum Matrix Evaluation
      if(MathAbs(current_slope) <= threshold)
        {
         color_buffer[i] = 0.0; // Index 0: clrGray (Neutral / Chop Regime)
        }
      else
         if(current_slope > 0.0)
           {
            if(current_slope > previous_slope)
               color_buffer[i] = 1.0; // Index 1: clrMediumSeaGreen (Strong Bullish Acceleration)
            else
               color_buffer[i] = 2.0; // Index 2: clrPaleGreen (Weak Bullish Deceleration)
           }
         else // current_slope < 0.0
           {
            if(current_slope < previous_slope)
               color_buffer[i] = 3.0; // Index 3: clrCrimson (Strong Bearish Acceleration)
            else
               color_buffer[i] = 4.0; // Index 4: clrLightCoral (Weak Bearish Deceleration)
           }
     }
  }

#endif // KAMA_SLOPE_CALCULATOR_MQH
//+------------------------------------------------------------------+
