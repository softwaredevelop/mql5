//+------------------------------------------------------------------+
//|                                   CG_Oscillator_Calculator.mqh   |
//|      Calculation engine for the John Ehlers' CG Oscillator.      |
//|      VERSION 2.10: Added option for Original Ehlers Calculation. |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|           CLASS 1: CCGOscillatorCalculator (Base Class)          |
//+==================================================================+
class CCGOscillatorCalculator
  {
protected:
   int               m_period;
   bool              m_original_mode; // New member for mode selection

   //--- Persistent Buffer for Incremental Calculation
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CCGOscillatorCalculator(void) {};
   virtual          ~CCGOscillatorCalculator(void) {};

   //--- Updated Init: accepts mode boolean
   bool              Init(int period, bool original_mode);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &cg_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CCGOscillatorCalculator::Init(int period, bool original_mode)
  {
   m_period = (period < 2) ? 2 : period;
   m_original_mode = original_mode;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CCGOscillatorCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                        double &cg_buffer[], double &signal_buffer[])
  {
   if(rates_total < m_period)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   int loop_start = MathMax(m_period - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double numerator = 0;
      double denominator = 0;

      for(int j = 0; j < m_period; j++)
        {
         double current_price = m_price[i - j];
         numerator += (j + 1) * current_price;
         denominator += current_price;
        }

      if(denominator != 0)
        {
         double raw_cg = -numerator / denominator;

         if(m_original_mode)
           {
            // Ehlers Original: Returns negative values representing array index position
            cg_buffer[i] = raw_cg;
           }
         else
           {
            // Pro Mode: Centers the oscillator around 0.0
            // Adds half the period length to offset the negative index
            cg_buffer[i] = raw_cg + (m_period + 1) / 2.0;
           }
        }
      else
        {
         cg_buffer[i] = 0;
        }
     }

//--- Calculate Signal Line (1-bar delay)
   int signal_start = loop_start;
   if(signal_start == 0)
      signal_start = 1;

   for(int i = signal_start; i < rates_total; i++)
     {
      signal_buffer[i] = cg_buffer[i-1];
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard)                                         |
//+------------------------------------------------------------------+
bool CCGOscillatorCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      m_price[i] = (high[i] + low[i]) / 2.0; // Median Price
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CCGOscillatorCalculator_HA                  |
//+==================================================================+
class CCGOscillatorCalculator_HA : public CCGOscillatorCalculator
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
bool CCGOscillatorCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   for(int i = start_index; i < rates_total; i++)
     {
      m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0; // Median Price HA
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
