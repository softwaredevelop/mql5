//+------------------------------------------------------------------+
//|                                Laguerre_Adaptive_Slope_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Adaptive Slope Calculator with 5-zone thermal classification
#property description "Calculator engine for analyzing the slope (1st derivative) of the Adaptive Laguerre Filter."

#ifndef LAGUERRE_ADAPTIVE_SLOPE_CALCULATOR_MQH
#define LAGUERRE_ADAPTIVE_SLOPE_CALCULATOR_MQH

#include <MyIncludes\Laguerre_Adaptive_Filter_Calculator.mqh>

//+==================================================================+
//|             CLASS: CLaguerreAdaptiveSlopeCalculator             |
//+==================================================================+
class CLaguerreAdaptiveSlopeCalculator
  {
private:
   CLaguerreAdaptiveFilterCalculator *m_filter_calc;
   double                             m_filter_buffer[];

public:
                     CLaguerreAdaptiveSlopeCalculator(void);
                    ~CLaguerreAdaptiveSlopeCalculator(void);

   bool              Init(ENUM_ADAPTIVE_METHOD method, int adaptive_period, double gamma_min, double gamma_max, bool is_ha);
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &slope_buffer[], double &color_buffer[], double threshold);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreAdaptiveSlopeCalculator::CLaguerreAdaptiveSlopeCalculator(void)
   : m_filter_calc(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreAdaptiveSlopeCalculator::~CLaguerreAdaptiveSlopeCalculator(void)
  {
   if(CheckPointer(m_filter_calc) != POINTER_INVALID)
      delete m_filter_calc;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreAdaptiveSlopeCalculator::Init(ENUM_ADAPTIVE_METHOD method, int adaptive_period, double gamma_min, double gamma_max, bool is_ha)
  {
   if(CheckPointer(m_filter_calc) != POINTER_INVALID)
      delete m_filter_calc;

   m_filter_calc = new CLaguerreAdaptiveFilterCalculator();
   if(CheckPointer(m_filter_calc) == POINTER_INVALID)
      return false;

   return m_filter_calc.Init(method, adaptive_period, gamma_min, gamma_max, is_ha);
  }

//+------------------------------------------------------------------+
//| Calculate (Optimized first derivative of Adaptive Filter)        |
//+------------------------------------------------------------------+
void CLaguerreAdaptiveSlopeCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &slope_buffer[], double &color_buffer[], double threshold)
  {
   if(CheckPointer(m_filter_calc) == POINTER_INVALID || rates_total < 3)
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

   if(start_index == 0)
     {
      slope_buffer[0] = 0.0;
      color_buffer[0] = 0.0; // Index 0: clrGray
      start_index = 1;
     }

//--- Slope differentiation: Slope = Filter[t] - Filter[t-1]
   for(int i = start_index; i < rates_total; i++)
     {
      slope_buffer[i] = m_filter_buffer[i] - m_filter_buffer[i - 1];

      double current_slope  = slope_buffer[i];
      double previous_slope = slope_buffer[i - 1];

      //--- Classify into 5-zone Symmetrical Momentum Matrix
      if(MathAbs(current_slope) <= threshold)
        {
         color_buffer[i] = 0.0; // Index 0: clrGray (Neutral / Consolidation)
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

#endif // LAGUERRE_ADAPTIVE_SLOPE_CALCULATOR_MQH
//+------------------------------------------------------------------+
