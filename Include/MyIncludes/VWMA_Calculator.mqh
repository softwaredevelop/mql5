//+------------------------------------------------------------------+
//|                                           VWMA_Calculator.mqh    |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.20" // Optimized for incremental calculation
#property description "Volume-Weighted Moving Average (VWMA) Math Engine"

#ifndef VWMA_CALCULATOR_MQH
#define VWMA_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS: CVWMA_Calculator                              |
//+==================================================================+
class CVWMA_Calculator
  {
protected:
   int               m_period;
   double            m_price[];
   double            m_volume[];

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CVWMA_Calculator(void) : m_period(20) {};
   virtual          ~CVWMA_Calculator(void) {};

   bool              Init(int period);

   //--- Core math execution with passed volume array
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[], double &output_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CVWMA_Calculator::Init(int period)
  {
   m_period = (period < 1) ? 1 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Incremental sliding calculation)                      |
//+------------------------------------------------------------------+
void CVWMA_Calculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[], double &output_buffer[])
  {
   if(rates_total < m_period)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

//--- Maintain internal buffer synchronization
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_volume, rates_total);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- Cast and cache volume data locally
   for(int i = start_index; i < rates_total; i++)
     {
      m_volume[i] = (double)volume[i];
     }

//--- Define boundaries for O(1) incremental update
   int start_pos = m_period - 1;
   int loop_start = MathMax(start_pos, start_index);

//--- VWMA Calculation Loop
   for(int i = loop_start; i < rates_total; i++)
     {
      double sum_pv = 0;
      double sum_v = 0;
      for(int j = 0; j < m_period; j++)
        {
         double v = m_volume[i - j];
         sum_pv += m_price[i - j] * v;
         sum_v  += v;
        }
      output_buffer[i] = (sum_v > 0) ? (sum_pv / sum_v) : m_price[i];
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CVWMA_Calculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (high[i] + low[i] + 2.0 * close[i]) / 4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS: CVWMA_Calculator_HA                           |
//+==================================================================+
class CVWMA_Calculator_HA : public CVWMA_Calculator
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
bool CVWMA_Calculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) / 4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }

#endif // VWMA_CALCULATOR_MQH
//+------------------------------------------------------------------+
