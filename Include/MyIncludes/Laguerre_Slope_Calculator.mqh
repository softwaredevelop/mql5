//+------------------------------------------------------------------+
//|                                   Laguerre_Slope_Calculator.mqh |
//|      Engine for Analyzing the Slope of Ehlers' Laguerre Filter   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Overloaded initialization, leak-free pointer management & bounds protection

#ifndef LAGUERRE_SLOPE_CALCULATOR_MQH
#define LAGUERRE_SLOPE_CALCULATOR_MQH

#include <MyIncludes\Laguerre_Filter_Calculator.mqh>

//+==================================================================+
//|             CLASS: CLaguerreSlopeCalculator                     |
//+==================================================================+
class CLaguerreSlopeCalculator
  {
private:
   double                     m_gamma;
   ENUM_INPUT_SOURCE          m_source_type;
   ENUM_APPLIED_PRICE_HA_ALL  m_source_price;
   CLaguerreFilterCalculator *m_filter_calc;

   //--- Persistent State Buffers
   double                     m_filter_buffer[];
   double                     m_dummy_fir[];

public:
                     CLaguerreSlopeCalculator(void);
                    ~CLaguerreSlopeCalculator(void);

   //--- Legacy Compatible Init (3 Parameters)
   bool                       Init(const double gamma, const ENUM_INPUT_SOURCE source_type, const bool is_ha)
     {
      ENUM_APPLIED_PRICE_HA_ALL src = is_ha ? PRICE_HA_CLOSE : PRICE_CLOSE_STD;
      return Init(gamma, source_type, src);
     }

   //--- Enhanced Pro Init (3 Parameters with Full Price Enum)
   bool                       Init(const double gamma, const ENUM_INPUT_SOURCE source_type, const ENUM_APPLIED_PRICE_HA_ALL price_source);

   void                       Calculate(const int rates_total, const int prev_calculated,
                                        const double &open[], const double &high[],
                                        const double &low[], const double &close[],
                                        double &slope_buffer[], double &color_buffer[],
                                        const double threshold);

   //--- Legacy Overload with price_type parameter
   void                       Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                        const double &open[], const double &high[],
                                        const double &low[], const double &close[],
                                        double &slope_buffer[], double &color_buffer[],
                                        const double threshold)
     {
      Calculate(rates_total, prev_calculated, open, high, low, close, slope_buffer, color_buffer, threshold);
     }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreSlopeCalculator::CLaguerreSlopeCalculator(void) : m_gamma(0.5),
   m_source_type(SOURCE_PRICE),
   m_source_price(PRICE_CLOSE_STD),
   m_filter_calc(NULL)
  {
   ArraySetAsSeries(m_filter_buffer, false);
   ArraySetAsSeries(m_dummy_fir,     false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreSlopeCalculator::~CLaguerreSlopeCalculator(void)
  {
   if(CheckPointer(m_filter_calc) != POINTER_INVALID)
     {
      delete m_filter_calc;
      m_filter_calc = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Enhanced Pro Initialization                                      |
//+------------------------------------------------------------------+
bool CLaguerreSlopeCalculator::Init(const double gamma, const ENUM_INPUT_SOURCE source_type, const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_gamma        = fmax(0.0, fmin(1.0, gamma));
   m_source_type  = source_type;
   m_source_price = price_source;

   if(CheckPointer(m_filter_calc) != POINTER_INVALID)
     {
      delete m_filter_calc;
      m_filter_calc = NULL;
     }

   if(m_source_price <= PRICE_HA_CLOSE)
      m_filter_calc = new CLaguerreFilterCalculator_HA();
   else
      m_filter_calc = new CLaguerreFilterCalculator();

   if(CheckPointer(m_filter_calc) == POINTER_INVALID)
      return false;

   return m_filter_calc.Init(m_gamma, m_source_type, m_source_price);
  }

//+------------------------------------------------------------------+
//| Main Incremental Slope Calculation Loop                          |
//+------------------------------------------------------------------+
void CLaguerreSlopeCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &slope_buffer[], double &color_buffer[],
      const double threshold)
  {
   if(rates_total < 3 || CheckPointer(m_filter_calc) == POINTER_INVALID)
      return;

// Safe allocation of destination arrays
   if(ArraySize(slope_buffer) != rates_total)
     {
      ArrayResize(slope_buffer, rates_total);
      ArraySetAsSeries(slope_buffer, false);
      ArrayInitialize(slope_buffer, 0.0);
     }
   if(ArraySize(color_buffer) != rates_total)
     {
      ArrayResize(color_buffer, rates_total);
      ArraySetAsSeries(color_buffer, false);
      ArrayInitialize(color_buffer, 0.0);
     }

// Resize internal filter cache
   if(ArraySize(m_filter_buffer) != rates_total)
     {
      ArrayResize(m_filter_buffer, rates_total);
      ArrayResize(m_dummy_fir,     rates_total);
      ArraySetAsSeries(m_filter_buffer, false);
      ArraySetAsSeries(m_dummy_fir,     false);
     }

// 1. Calculate Underlying Laguerre Filter
   m_filter_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_filter_buffer, m_dummy_fir);

   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : 0;

   if(prev_calculated == 0)
     {
      slope_buffer[0] = 0.0;
      color_buffer[0] = 0.0; // Index 0: clrGray (Neutral)
      start_index = 1;
     }

// 2. Primary Slope Derivative Loop: Slope = Laguerre[t] - Laguerre[t-1]
   for(int i = start_index; i < rates_total; i++)
     {
      if(m_filter_buffer[i] == EMPTY_VALUE || m_filter_buffer[i - 1] == EMPTY_VALUE)
        {
         slope_buffer[i] = 0.0;
         color_buffer[i] = 0.0;
         continue;
        }

      slope_buffer[i] = m_filter_buffer[i] - m_filter_buffer[i - 1];

      double current_slope  = slope_buffer[i];
      double previous_slope = slope_buffer[i - 1];

      // 3. Symmetrical 5-Zone Momentum Matrix
      if(MathAbs(current_slope) <= threshold)
        {
         color_buffer[i] = 0.0; // Index 0: clrGray (Neutral / Consolidation)
        }
      else
         if(current_slope > 0.0)
           {
            if(current_slope > previous_slope)
               color_buffer[i] = 1.0; // Index 1: clrMediumSeaGreen (Strong Bull Acceleration)
            else
               color_buffer[i] = 2.0; // Index 2: clrPaleGreen (Weak Bull Deceleration)
           }
         else // current_slope < 0.0
           {
            if(current_slope < previous_slope)
               color_buffer[i] = 3.0; // Index 3: clrCrimson (Strong Bear Acceleration)
            else
               color_buffer[i] = 4.0; // Index 4: clrLightCoral (Weak Bear Deceleration)
           }
     }
  }

#endif // LAGUERRE_SLOPE_CALCULATOR_MQH
//+------------------------------------------------------------------+
