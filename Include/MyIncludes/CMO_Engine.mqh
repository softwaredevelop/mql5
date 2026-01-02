//+------------------------------------------------------------------+
//|                                               CMO_Engine.mqh     |
//|      Core engine for Chande Momentum Oscillator calculation.     |
//|      VERSION 1.00: Pure CMO logic (no signal/bands).             |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CCMOEngine (Base Class)                     |
//+==================================================================+
class CCMOEngine
  {
protected:
   int               m_cmo_period;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];
   double            m_cmo_buffer[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

   //--- Helper to get a single CMO value
   double            GetCMOValue(int index);

public:
                     CCMOEngine(void) {};
   virtual          ~CCMOEngine(void) {};

   bool              Init(int cmo_p);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &cmo_out[]);

   int               GetPeriod(void) const { return m_cmo_period; }
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CCMOEngine::Init(int cmo_p)
  {
   m_cmo_period = (cmo_p < 1) ? 1 : cmo_p;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CCMOEngine::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &cmo_out[])
  {
   if(rates_total <= m_cmo_period)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_cmo_buffer, rates_total);
     }

// Resize output buffer if needed (if passed from outside)
   if(ArraySize(cmo_out) != rates_total)
      ArrayResize(cmo_out, rates_total);

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   int loop_start = MathMax(m_cmo_period, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      m_cmo_buffer[i] = GetCMOValue(i);
      cmo_out[i] = m_cmo_buffer[i];
     }
  }

//+------------------------------------------------------------------+
//| Helper: Calculate Single CMO Value                               |
//+------------------------------------------------------------------+
double CCMOEngine::GetCMOValue(int index)
  {
   double sum_up = 0.0, sum_down = 0.0;

   for(int j = 0; j < m_cmo_period; j++)
     {
      double diff = m_price[index - j] - m_price[index - j - 1];
      if(diff > 0.0)
         sum_up += diff;
      else
         sum_down += (-diff);
     }

   double total_sum = sum_up + sum_down;
   if(total_sum == 0.0)
      return 0.0;
   else
      return 100.0 * (sum_up - sum_down) / total_sum;
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CCMOEngine::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|             CLASS 2: CCMOEngine_HA (Heikin Ashi)                 |
//+==================================================================+
class CCMOEngine_HA : public CCMOEngine
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];
protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CCMOEngine_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
