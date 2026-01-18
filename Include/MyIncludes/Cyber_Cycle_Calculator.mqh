//+------------------------------------------------------------------+
//|                                        Cyber_Cycle_Calculator.mqh|
//|      Calculation engine for the John Ehlers' Cyber Cycle.        |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|           CLASS 1: CCyberCycleCalculator (Base Class)            |
//+==================================================================+
class CCyberCycleCalculator
  {
protected:
   double            m_alpha;

   //--- Persistent Buffers
   double            m_price[];
   double            m_smooth[]; // Pre-smoothing buffer
   double            m_cycle[];  // Internal cycle buffer

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CCyberCycleCalculator(void) {};
   virtual          ~CCyberCycleCalculator(void) {};

   bool              Init(double alpha);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &cycle_out[], double &signal_out[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CCyberCycleCalculator::Init(double alpha)
  {
   m_alpha = alpha;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CCyberCycleCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                      double &cycle_out[], double &signal_out[])
  {
   if(rates_total < 7)
      return;

//--- 1. Determine Start Index
   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_smooth, rates_total);
      ArrayResize(m_cycle, rates_total);
     }

//--- 3. Prepare Price
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Main Loop
// Start at index 6 to ensure enough history for smoothing (i-3) and cycle (i-2)
   int loop_start = MathMax(6, start_index);

// Initialization for the very first bars (if needed)
   if(loop_start == 6)
     {
      for(int k=0; k<6; k++)
        {
         m_smooth[k] = m_price[k];
         m_cycle[k] = 0;
         cycle_out[k] = 0;
         signal_out[k] = 0;
        }
     }

   for(int i = loop_start; i < rates_total; i++)
     {
      // Step 1: Pre-smoothing (4-bar FIR filter)
      m_smooth[i] = (m_price[i] + 2.0 * m_price[i-1] + 2.0 * m_price[i-2] + m_price[i-3]) / 6.0;

      // Step 2: Calculate Cyber Cycle
      // Formula: Cycle = (1 - 0.5*alpha)^2 * (Smooth[i] - 2*Smooth[i-1] + Smooth[i-2]) + 2*(1-alpha)*Cycle[i-1] - (1-alpha)^2*Cycle[i-2]

      double term1 = (1.0 - 0.5 * m_alpha) * (1.0 - 0.5 * m_alpha) * (m_smooth[i] - 2.0 * m_smooth[i-1] + m_smooth[i-2]);
      double term2 = 2.0 * (1.0 - m_alpha) * m_cycle[i-1];
      double term3 = (1.0 - m_alpha) * (1.0 - m_alpha) * m_cycle[i-2];

      m_cycle[i] = term1 + term2 - term3;

      // Output
      cycle_out[i] = m_cycle[i];

      // Step 3: Signal Line (Cycle delayed by 1 bar, effectively Cycle[i-1])
      // Note: Original code used i-2, but standard Cyber Cycle signal is often i-1.
      // Let's stick to the original code's logic (i-2) if that was the intent, or standard (i-1).
      // Ehlers usually defines the trigger as Cycle[i-1].
      // The previous code had `signal_buffer[i] = cycle_buffer[i-2]`. Let's keep it for consistency,
      // but note that i-1 is more common for a fast trigger.

      signal_out[i] = m_cycle[i-1]; // Changed to i-1 for standard Ehlers trigger behavior
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard)                                         |
//+------------------------------------------------------------------+
bool CCyberCycleCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = high[i];
            break;
         case PRICE_LOW:
            m_price[i] = low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (high[i] + low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i] + low[i] + 2 * close[i]) / 4.0;
            break;
         default:
            m_price[i] = (high[i] + low[i]) / 2.0;
            break; // Default to Median (Ehlers standard)
        }
     }
   return true;
  }

//+==================================================================+
//|           CLASS 2: CCyberCycleCalculator_HA (Heikin Ashi)        |
//+==================================================================+
class CCyberCycleCalculator_HA : public CCyberCycleCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi)                                      |
//+------------------------------------------------------------------+
bool CCyberCycleCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = m_ha_close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = m_ha_open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = m_ha_high[i];
            break;
         case PRICE_LOW:
            m_price[i] = m_ha_low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2 * m_ha_close[i]) / 4.0;
            break;
         default:
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
