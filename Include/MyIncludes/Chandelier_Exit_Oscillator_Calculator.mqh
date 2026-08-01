//+------------------------------------------------------------------+
//|                             Chandelier_Exit_Oscillator_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.01" // Patched Heikin Ashi close pricing bug by passing real high/low arrays
#property description "Stateful calculator implementing normalized distance between Price and Trailing Stop."

#ifndef CHANDELIER_EXIT_OSCILLATOR_CALCULATOR_MQH
#define CHANDELIER_EXIT_OSCILLATOR_CALCULATOR_MQH

#include <MyIncludes\Chandelier_Exit_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS: CChandelierExitOscillatorCalculator           |
//+==================================================================+
class CChandelierExitOscillatorCalculator
  {
private:
   int                        m_period;
   double                     m_multiplier;
   bool                       m_is_ha;

   CChandelierExitCalculator *m_exit_calc;
   CATRCalculator            *m_atr_calc;

   // Internal Caches
   double                     m_stop_line[];
   double                     m_color_dummy[];
   double                     m_atr_buffer[];
   double                     m_price_close[];

   // FIXED: Accepts full high[] and low[] arrays for pristine Heikin Ashi close calculation
   bool                       PrepareCloseSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CChandelierExitOscillatorCalculator(void);
                    ~CChandelierExitOscillatorCalculator(void);

   bool                       Init(int period, double multiplier, bool is_ha);
   void                       Calculate(int rates_total, int prev_calculated,
                                        const double &open[], const double &high[], const double &low[], const double &close[],
                                        double &osc_buffer[], double &color_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CChandelierExitOscillatorCalculator::CChandelierExitOscillatorCalculator(void)
   : m_period(22),
     m_multiplier(3.0),
     m_is_ha(false),
     m_exit_calc(NULL),
     m_atr_calc(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CChandelierExitOscillatorCalculator::~CChandelierExitOscillatorCalculator(void)
  {
   if(CheckPointer(m_exit_calc) != POINTER_INVALID)
      delete m_exit_calc;
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
      delete m_atr_calc;
  }

//+------------------------------------------------------------------+
//| Init (Polymorphic Engines Caching)                               |
//+------------------------------------------------------------------+
bool CChandelierExitOscillatorCalculator::Init(int period, double multiplier, bool is_ha)
  {
   m_period     = (period < 1) ? 1 : period;
   m_multiplier = (multiplier <= 0.0) ? 3.0 : multiplier;
   m_is_ha      = is_ha;

   if(CheckPointer(m_exit_calc) != POINTER_INVALID)
     {
      delete m_exit_calc;
      m_exit_calc = NULL;
     }
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
     {
      delete m_atr_calc;
      m_atr_calc = NULL;
     }

// 1. Instantiate Trailing Stop calculator (Polymorphic Std/HA internally)
   m_exit_calc = new CChandelierExitCalculator();
   if(CheckPointer(m_exit_calc) == POINTER_INVALID || !m_exit_calc.Init(m_period, m_multiplier, m_is_ha))
      return false;

// 2. Instantiate Raw ATR calculator (Polymorphic Std/HA internally)
   if(m_is_ha)
      m_atr_calc = new CATRCalculator_HA();
   else
      m_atr_calc = new CATRCalculator();

   if(CheckPointer(m_atr_calc) == POINTER_INVALID || !m_atr_calc.Init(m_period, ATR_POINTS))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Normalized Volatility Distance)                       |
//+------------------------------------------------------------------+
void CChandelierExitOscillatorCalculator::Calculate(int rates_total, int prev_calculated,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &osc_buffer[], double &color_buffer[])
  {
   if(rates_total < m_period + 5)
      return;

//--- Resize state buffers and enforce chronological safety
   if(ArraySize(m_stop_line) != rates_total)
     {
      ArrayResize(m_stop_line,    rates_total);
      ArrayResize(m_color_dummy,  rates_total);
      ArrayResize(m_atr_buffer,   rates_total);
      ArrayResize(m_price_close,  rates_total);

      ArraySetAsSeries(m_stop_line,    false);
      ArraySetAsSeries(m_color_dummy,  false);
      ArraySetAsSeries(m_atr_buffer,   false);
      ArraySetAsSeries(m_price_close,  false);
     }

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// FIXED: Passing full OHLC context to prevent pricing collapse
   if(!PrepareCloseSeries(rates_total, start_index, open, high, low, close))
      return;

//--- Run underlying Chandelier Exit Stop calculation
   m_exit_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_stop_line, m_color_dummy);

//--- Run underlying ATR calculation
   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

   int loop_start = MathMax(m_period, start_index);
   if(loop_start == m_period)
     {
      for(int i = 0; i < m_period; i++)
        {
         osc_buffer[i]   = 0.0;
         color_buffer[i] = 0.0;
        }
     }

//--- Compute Normalized Distance: (Price - Stop) / ATR
   for(int i = loop_start; i < rates_total; i++)
     {
      double atr = m_atr_buffer[i];
      if(atr > 1.0e-9)
        {
         osc_buffer[i] = (m_price_close[i] - m_stop_line[i]) / atr;
        }
      else
        {
         osc_buffer[i] = 0.0;
        }

      // Color mapping aligned with the trend flip
      // If above 0.0 -> DodgerBlue (Bullish)
      // If below 0.0 -> Tomato (Bearish)
      color_buffer[i] = (osc_buffer[i] >= 0.0) ? 0.0 : 1.0;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Close price (Standard or HA - Clean Execution)           |
//+------------------------------------------------------------------+
bool CChandelierExitOscillatorCalculator::PrepareCloseSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(m_is_ha)
     {
      static CHeikinAshi_Calculator ha_calc;
      static double ha_open[], ha_high[], ha_low[], ha_close[];
      if(ArraySize(ha_open) != rates_total)
        {
         ArrayResize(ha_open,  rates_total);
         ArrayResize(ha_high,  rates_total);
         ArrayResize(ha_low,   rates_total);
         ArrayResize(ha_close, rates_total);

         ArraySetAsSeries(ha_open,  false);
         ArraySetAsSeries(ha_high,  false);
         ArraySetAsSeries(ha_low,   false);
         ArraySetAsSeries(ha_close, false);
        }

      // FIXED: Real high[] and low[] arrays passed to the HA toolkit to obtain correct prices
      ha_calc.Calculate(rates_total, start_index, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

      for(int i = start_index; i < rates_total; i++)
         m_price_close[i] = ha_close[i];
     }
   else
     {
      for(int i = start_index; i < rates_total; i++)
         m_price_close[i] = close[i];
     }
   return true;
  }

#endif // CHANDELIER_EXIT_OSCILLATOR_CALCULATOR_MQH
//+------------------------------------------------------------------+
