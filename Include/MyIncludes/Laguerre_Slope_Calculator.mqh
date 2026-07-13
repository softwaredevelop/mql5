//+------------------------------------------------------------------+
//|                                   Laguerre_Slope_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Optimized for incremental calculations
#property description "Calculator engine for analyzing and classifying the slope of Ehlers Laguerre Filter."

#ifndef LAGUERRE_SLOPE_CALCULATOR_MQH
#define LAGUERRE_SLOPE_CALCULATOR_MQH

#include <MyIncludes\Laguerre_Filter_Calculator.mqh>

//+==================================================================+
//|             CLASS: CLaguerreSlopeCalculator                     |
//+==================================================================+
class CLaguerreSlopeCalculator
  {
private:
   CLaguerreFilterCalculator *m_filter_calc;
   double                     m_filter_buffer[];
   double                     m_dummy_fir[];

public:
                     CLaguerreSlopeCalculator(void);
                    ~CLaguerreSlopeCalculator(void);

   bool              Init(double gamma, ENUM_INPUT_SOURCE source_type, bool is_ha);
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &slope_buffer[], double &color_buffer[], double threshold);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreSlopeCalculator::CLaguerreSlopeCalculator(void)
   : m_filter_calc(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreSlopeCalculator::~CLaguerreSlopeCalculator(void)
  {
   if(CheckPointer(m_filter_calc) != POINTER_INVALID)
      delete m_filter_calc;
  }

//+------------------------------------------------------------------+
//| Initialization with Dynamic Factory logic for Standard / HA      |
//+------------------------------------------------------------------+
bool CLaguerreSlopeCalculator::Init(double gamma, ENUM_INPUT_SOURCE source_type, bool is_ha)
  {
   if(CheckPointer(m_filter_calc) != POINTER_INVALID)
      delete m_filter_calc;

   if(is_ha)
      m_filter_calc = new CLaguerreFilterCalculator_HA();
   else
      m_filter_calc = new CLaguerreFilterCalculator();

   if(CheckPointer(m_filter_calc) == POINTER_INVALID)
      return false;

   return m_filter_calc.Init(gamma, source_type);
  }

//+------------------------------------------------------------------+
//| Performance-first Incremental Slope Calculation                  |
//+------------------------------------------------------------------+
void CLaguerreSlopeCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &slope_buffer[], double &color_buffer[], double threshold)
  {
   if(CheckPointer(m_filter_calc) == POINTER_INVALID || rates_total < 2)
      return;

//--- Prevent memory reallocations where possible, keeping state buffers aligned
   if(ArraySize(m_filter_buffer) != rates_total)
     {
      ArrayResize(m_filter_buffer, rates_total);
      ArrayResize(m_dummy_fir, rates_total);
      ArraySetAsSeries(m_filter_buffer, false);
      ArraySetAsSeries(m_dummy_fir, false);
     }

//--- Call inner Laguerre Filter Engine (O(1) stateful transition internally)
   m_filter_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_filter_buffer, m_dummy_fir);

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   if(start_index == 0)
     {
      slope_buffer[0] = 0.0;
      color_buffer[0] = 0.0; // Index 0: clrGray (Neutral)
      start_index = 1;
     }

//--- Primary analytical loop
   for(int i = start_index; i < rates_total; i++)
     {
      slope_buffer[i] = m_filter_buffer[i] - m_filter_buffer[i - 1];

      double current_slope = slope_buffer[i];
      double previous_slope = slope_buffer[i - 1];

      //--- Classification into 5-zone symmetrical thermal matrix
      if(MathAbs(current_slope) <= threshold)
        {
         color_buffer[i] = 0.0; // Neutral (clrGray)
        }
      else
         if(current_slope > 0.0)
           {
            if(current_slope > previous_slope)
               color_buffer[i] = 1.0; // Strong Bullish (clrMediumSeaGreen)
            else
               color_buffer[i] = 2.0; // Weak Bullish (clrPaleGreen)
           }
         else // current_slope < 0.0
           {
            if(current_slope < previous_slope)
               color_buffer[i] = 3.0; // Strong Bearish (clrCrimson)
            else
               color_buffer[i] = 4.0; // Weak Bearish (clrLightCoral)
           }
     }
  }

#endif // LAGUERRE_SLOPE_CALCULATOR_MQH
//+------------------------------------------------------------------+
