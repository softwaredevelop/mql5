//+------------------------------------------------------------------+
//|                                              MADH_Calculator.mqh |
//|      Calculation engine for the John Ehlers' MADH indicator.     |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CMADHCalculator (Base Class)                |
//+==================================================================+
class CMADHCalculator
  {
protected:
   int               m_short_len;
   int               m_dom_cycle;

   //--- Persistent Buffer for Incremental Calculation
   double            m_price[];

   // Helper function to calculate a Hann-windowed Moving Average
   double            CalcHWMA(int position, int period, const double &price_array[]);

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CMADHCalculator(void) {};
   virtual          ~CMADHCalculator(void) {};

   bool              Init(int short_len, int dom_cycle);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &madh_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMADHCalculator::Init(int short_len, int dom_cycle)
  {
   m_short_len = (short_len < 1) ? 1 : short_len;
   m_dom_cycle = (dom_cycle < 1) ? 1 : dom_cycle;
   return true;
  }

//+------------------------------------------------------------------+
//| Helper function to calculate a Hann-windowed Moving Average      |
//+------------------------------------------------------------------+
double CMADHCalculator::CalcHWMA(int position, int period, const double &price_array[])
  {
   if(position < period - 1)
      return 0.0;

   double sum = 0;
   double coef_sum = 0;

// Optimization: Pre-calculate weights in Init?
// Since period can be different (short vs long), we keep it local or use a map.
// For typical periods, local calculation is fast enough.

   for(int i = 0; i < period; i++)
     {
      double weight = 1.0 - cos(2 * M_PI * (i + 1.0) / (period + 1.0));
      sum += weight * price_array[position - i];
      coef_sum += weight;
     }

   if(coef_sum > 0)
      return sum / coef_sum;

   return 0.0;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CMADHCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &madh_buffer[])
  {
   int long_len = m_short_len + (int)round(m_dom_cycle / 2.0);
   if(rates_total < long_len)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffer
   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Calculate MADH (Incremental Loop)
   int loop_start = MathMax(long_len - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      // Step 1 & 2: Calculate the two HWMA filters
      double filt1 = CalcHWMA(i, m_short_len, m_price);
      double filt2 = CalcHWMA(i, long_len, m_price);

      // Step 3: Calculate the final MADH value
      if(filt2 != 0)
        {
         madh_buffer[i] = 100.0 * (filt1 - filt2) / filt2;
        }
      else
        {
         madh_buffer[i] = 0;
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CMADHCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (high[i]+low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CMADHCalculator_HA (Heikin Ashi)            |
//+==================================================================+
class CMADHCalculator_HA : public CMADHCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];
protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CMADHCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (m_ha_high[i]+m_ha_low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+m_ha_close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+2*m_ha_close[i])/4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
