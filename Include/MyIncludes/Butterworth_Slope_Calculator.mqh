//+------------------------------------------------------------------+
//|                                   Butterworth_Slope_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Performance optimized first derivative of Butterworth Filter
#property description "Calculator engine for analyzing the slope (1st derivative) of Butterworth Filter."

#ifndef BUTTERWORTH_SLOPE_CALCULATOR_MQH
#define BUTTERWORTH_SLOPE_CALCULATOR_MQH

#include <MyIncludes\Butterworth_Calculator.mqh>

//+==================================================================+
//|             CLASS: CButterworthSlopeCalculator                   |
//+==================================================================+
class CButterworthSlopeCalculator
  {
private:
   CButterworthCalculator *m_filter_calc;
   double                  m_filter_buffer[];

public:
                     CButterworthSlopeCalculator(void);
                    ~CButterworthSlopeCalculator(void);

   bool                    Init(int period, ENUM_BUTTERWORTH_POLES poles, bool is_ha);
   void                    Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                     const double &open[], const double &high[], const double &low[], const double &close[],
                                     double &slope_buffer[], double &color_buffer[], double threshold);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CButterworthSlopeCalculator::CButterworthSlopeCalculator(void)
   : m_filter_calc(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CButterworthSlopeCalculator::~CButterworthSlopeCalculator(void)
  {
   if(CheckPointer(m_filter_calc) != POINTER_INVALID)
      delete m_filter_calc;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CButterworthSlopeCalculator::Init(int period, ENUM_BUTTERWORTH_POLES poles, bool is_ha)
  {
   if(CheckPointer(m_filter_calc) != POINTER_INVALID)
      delete m_filter_calc;

   if(is_ha)
      m_filter_calc = new CButterworthCalculator_HA();
   else
      m_filter_calc = new CButterworthCalculator();

   if(CheckPointer(m_filter_calc) == POINTER_INVALID)
      return false;

   return m_filter_calc.Init(period, poles, SOURCE_PRICE);
  }

//+------------------------------------------------------------------+
//| Calculate                                                        |
//+------------------------------------------------------------------+
void CButterworthSlopeCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &slope_buffer[], double &color_buffer[], double threshold)
  {
   if(CheckPointer(m_filter_calc) == POINTER_INVALID || rates_total < 5)
      return;

//--- Resize state buffers and enforce chronological safety
   if(ArraySize(m_filter_buffer) != rates_total)
     {
      ArrayResize(m_filter_buffer, rates_total);
      ArraySetAsSeries(m_filter_buffer, false);
     }

//--- Calculate underlying Butterworth filter
   m_filter_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_filter_buffer);

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   if(start_index == 0)
     {
      slope_buffer[0] = 0.0;
      color_buffer[0] = 0.0; // Index 0: clrGray
      start_index = 1;
     }

//--- Slope calculation loop: Slope = Filter[t] - Filter[t-1]
   for(int i = start_index; i < rates_total; i++)
     {
      slope_buffer[i] = m_filter_buffer[i] - m_filter_buffer[i - 1];

      double current_slope  = slope_buffer[i];
      double previous_slope = slope_buffer[i - 1];

      //--- Symmetrical 5-Zone Momentum Matrix
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

#endif // BUTTERWORTH_SLOPE_CALCULATOR_MQH
//+------------------------------------------------------------------+
