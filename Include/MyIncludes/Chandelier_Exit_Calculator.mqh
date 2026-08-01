//+------------------------------------------------------------------+
//|                                   Chandelier_Exit_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.20" // Integrated strict Directional Safety Filter to eliminate sawtooth death-loops
#property description "Stateful calculator implementing Charles LeBeau Chandelier Exit (ATR Trailing Stop)."

#ifndef CHANDELIER_EXIT_CALCULATOR_MQH
#define CHANDELIER_EXIT_CALCULATOR_MQH

#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS: CChandelierExitCalculator                     |
//+==================================================================+
class CChandelierExitCalculator
  {
private:
   int               m_period;
   double            m_multiplier;
   bool              m_is_ha;

   CATRCalculator    *m_atr_calc;
   double            m_atr_buffer[];

   // Persistent Price Caches
   double            m_price_high[];
   double            m_price_low[];
   double            m_price_close[];

   // Persistent State Registers for Trailing Stop ratchets
   double            m_long_stop[];
   double            m_short_stop[];
   double            m_trend[];

   double            Highest(const double &array[], int period, int current_pos);
   double            Lowest(const double &array[], int period, int current_pos);
   bool              PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CChandelierExitCalculator(void);
                    ~CChandelierExitCalculator(void);

   bool              Init(int period, double multiplier, bool is_ha);
   void              Calculate(int rates_total, int prev_calculated,
                             const double &open[], const double &high[], const double &low[], const double &close[],
                             double &stop_line[], double &color_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CChandelierExitCalculator::CChandelierExitCalculator(void)
   : m_period(22),
     m_multiplier(3.0),
     m_is_ha(false),
     m_atr_calc(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CChandelierExitCalculator::~CChandelierExitCalculator(void)
  {
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
      delete m_atr_calc;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CChandelierExitCalculator::Init(int period, double multiplier, bool is_ha)
  {
   m_period     = (period < 1) ? 1 : period;
   m_multiplier = (multiplier <= 0.0) ? 3.0 : multiplier;
   m_is_ha      = is_ha;

   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
     {
      delete m_atr_calc;
      m_atr_calc = NULL;
     }

   if(m_is_ha)
      m_atr_calc = new CATRCalculator_HA();
   else
      m_atr_calc = new CATRCalculator();

   if(CheckPointer(m_atr_calc) == POINTER_INVALID || !m_atr_calc.Init(m_period, ATR_POINTS))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Stateful O(1) Trailing Stop logic)                    |
//+------------------------------------------------------------------+
void CChandelierExitCalculator::Calculate(int rates_total, int prev_calculated,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &stop_line[], double &color_buffer[])
  {
   if(rates_total < m_period + 5)
      return;

//--- Resize state buffers and enforce chronological safety
   if(ArraySize(m_atr_buffer) != rates_total)
     {
      ArrayResize(m_atr_buffer,  rates_total);
      ArrayResize(m_price_high,  rates_total);
      ArrayResize(m_price_low,   rates_total);
      ArrayResize(m_price_close, rates_total);
      ArrayResize(m_long_stop,   rates_total);
      ArrayResize(m_short_stop,  rates_total);
      ArrayResize(m_trend,       rates_total);

      ArraySetAsSeries(m_atr_buffer,  false);
      ArraySetAsSeries(m_price_high,  false);
      ArraySetAsSeries(m_price_low,   false);
      ArraySetAsSeries(m_price_close, false);
      ArraySetAsSeries(m_long_stop,   false);
      ArraySetAsSeries(m_short_stop,  false);
      ArraySetAsSeries(m_trend,       false);
     }

//--- 1. Prepare Source Price Data (Standard or HA)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

//--- 2. Calculate volatility baseline using refactored ATR v3.00
   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

   int loop_start = MathMax(m_period, start_index);

//--- 3. Warm-up Initialization
   if(loop_start == m_period)
     {
      for(int i = 0; i < m_period; i++)
        {
         m_long_stop[i]  = 0.0;
         m_short_stop[i] = 0.0;
         m_trend[i]      = 1.0;
         stop_line[i]    = m_price_close[i];
         color_buffer[i] = 0.0;
        }
     }

//--- 4. Calculate Raw Stop Bands
   for(int i = loop_start; i < rates_total; i++)
     {
      m_long_stop[i]  = Highest(m_price_high, m_period, i) - m_multiplier * m_atr_buffer[i];
      m_short_stop[i] = Lowest(m_price_low, m_period, i) + m_multiplier * m_atr_buffer[i];
     }

//--- 5. Trailing Stop Ratchet & Trend Logic (FIXED: Strict Directional Safety Filter applied)
   for(int i = loop_start; i < rates_total; i++)
     {
      double prev_stop  = stop_line[i - 1];
      double prev_trend = m_trend[i - 1];

      if(prev_trend == 1.0) // Trend was Bullish (stop is below price)
        {
         // Flip to bearish ONLY if price closes BELOW active stop AND the new bearish stop is safely ABOVE price
         if(m_price_close[i] < prev_stop && m_short_stop[i] > m_price_close[i])
           {
            m_trend[i]   = -1.0;
            stop_line[i] = m_short_stop[i]; // Reset to ShortStop
           }
         else
           {
            m_trend[i]   = 1.0;
            // Ratchet trailing: stop can only go up
            stop_line[i] = MathMax(m_long_stop[i], prev_stop);
           }
        }
      else // Trend was Bearish (prev_trend == -1.0, stop is above price)
        {
         // Flip to bullish ONLY if price closes ABOVE active stop AND the new bullish stop is safely BELOW price
         if(m_price_close[i] > prev_stop && m_long_stop[i] < m_price_close[i])
           {
            m_trend[i]   = 1.0;
            stop_line[i] = m_long_stop[i]; // Reset to LongStop
           }
         else
           {
            m_trend[i]   = -1.0;
            // Ratchet trailing: stop can only go down
            stop_line[i] = MathMin(m_short_stop[i], prev_stop);
           }
        }

      // Assign visual color indexes cleanly
      if(m_trend[i] == 1.0)
        {
         color_buffer[i] = 0.0; // Index 0: Bullish (clrDodgerBlue)
        }
      else
        {
         color_buffer[i] = 1.0; // Index 1: Bearish (clrTomato)
        }

      // Connect lines on trend transitions (MT5 drawing trick for color lines)
      if(m_trend[i] != m_trend[i - 1])
        {
         if(m_trend[i] == 1.0)
            stop_line[i - 1] = m_long_stop[i];
         else
            stop_line[i - 1] = m_short_stop[i];
        }
     }
  }

//+------------------------------------------------------------------+
//| Find Highest Value over Period                                   |
//+------------------------------------------------------------------+
double CChandelierExitCalculator::Highest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      if(current_pos - i < 0)
         break;
      if(res < array[current_pos - i])
         res = array[current_pos - i];
     }
   return res;
  }

//+------------------------------------------------------------------+
//| Find Lowest Value over Period                                    |
//+------------------------------------------------------------------+
double CChandelierExitCalculator::Lowest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      if(current_pos - i < 0)
         break;
      if(res > array[current_pos - i])
         res = array[current_pos - i];
     }
   return res;
  }

//+------------------------------------------------------------------+
//| Prepare Source Data Series (Standard or Heikin Ashi)             |
//+------------------------------------------------------------------+
bool CChandelierExitCalculator::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
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

      ha_calc.Calculate(rates_total, start_index, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

      for(int i = start_index; i < rates_total; i++)
        {
         m_price_high[i]  = ha_high[i];
         m_price_low[i]   = ha_low[i];
         m_price_close[i] = ha_close[i];
        }
     }
   else
     {
      for(int i = start_index; i < rates_total; i++)
        {
         m_price_high[i]  = high[i];
         m_price_low[i]   = low[i];
         m_price_close[i] = close[i];
        }
     }
   return true;
  }

#endif // CHANDELIER_EXIT_CALCULATOR_MQH
//+------------------------------------------------------------------+
