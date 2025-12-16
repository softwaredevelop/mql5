//+------------------------------------------------------------------+
//|                                               HMA_Calculator.mqh |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CHMACalculator (Base Class)                 |
//+==================================================================+
class CHMACalculator
  {
protected:
   int               m_hma_period;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];
   double            m_raw_hma[]; // Intermediate buffer for the 3rd WMA

   //--- Helper function for manual WMA calculation
   double            CalculateWMA(int period, int index, const double &source_array[]);

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CHMACalculator(void) {};
   virtual          ~CHMACalculator(void) {};

   bool              Init(int period);
   int               GetPeriod(void) const { return m_hma_period; }

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &hma_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CHMACalculator::Init(int period)
  {
   m_hma_period = (period < 1) ? 1 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CHMACalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &hma_buffer[])
  {
   int period_sqrt = (int)MathMax(1, MathRound(MathSqrt(m_hma_period)));
   int start_pos = m_hma_period + period_sqrt - 2;
   if(rates_total <= start_pos)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_raw_hma, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Calculate Intermediate WMAs (Incremental)
   int period_half = (int)MathMax(1, MathRound(m_hma_period / 2.0));
   int loop_start_raw = MathMax(m_hma_period - 1, start_index);

   for(int i = loop_start_raw; i < rates_total; i++)
     {
      double wma_half = CalculateWMA(period_half, i, m_price);
      double wma_full = CalculateWMA(m_hma_period, i, m_price);
      m_raw_hma[i] = 2 * wma_half - wma_full;
     }

//--- 5. Calculate Final HMA (Incremental)
// Uses m_raw_hma which is persistent
   int loop_start_final = MathMax(start_pos, start_index);

   for(int i = loop_start_final; i < rates_total; i++)
     {
      hma_buffer[i] = CalculateWMA(period_sqrt, i, m_raw_hma);
     }
  }

//+------------------------------------------------------------------+
//| Helper for WMA                                                   |
//+------------------------------------------------------------------+
double CHMACalculator::CalculateWMA(int period, int index, const double &source_array[])
  {
   double lwma_sum = 0, weight_sum = 0;
   for(int j=0; j<period; j++)
     {
      int weight = period - j;
      lwma_sum += source_array[index-j] * weight;
      weight_sum += weight;
     }
   return (weight_sum > 0) ? lwma_sum / weight_sum : 0.0;
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CHMACalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Optimized copy loop
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
//|             CLASS 2: CHMACalculator_HA (Heikin Ashi)             |
//+==================================================================+
class CHMACalculator_HA : public CHMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CHMACalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

//--- Copy to m_price (Optimized loop)
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
