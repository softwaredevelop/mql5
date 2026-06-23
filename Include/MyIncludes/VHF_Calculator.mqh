//+------------------------------------------------------------------+
//|                                            VHF_Calculator.mqh    |
//|      Engine for Vertical Horizontal Filter (Adam White).         |
//|      Algorithm: Selectable (Standard Close vs High-Low Range).   |
//|      VERSION 1.10: Added Heikin Ashi smoothing pipeline support  |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10"

#ifndef VHF_CALCULATOR_MQH
#define VHF_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

enum ENUM_VHF_MODE
  {
   VHF_MODE_CLOSE_ONLY, // Adam White Classic (Highest Close - Lowest Close)
   VHF_MODE_HIGH_LOW    // Professional (Highest High - Lowest Low)
  };

//+==================================================================+
//|             CLASS 1: CVHFCalculator (Base Class)                 |
//+==================================================================+
class CVHFCalculator
  {
protected:
   int               m_period;
   ENUM_VHF_MODE     m_mode;

   // Data Buffers
   double            m_price[]; // Close/Source Price (Denominator)
   double            m_high[];  // High Prices (Numerator High-Low Mode)
   double            m_low[];   // Low Prices (Numerator High-Low Mode)

   virtual bool      PrepareData(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type,
                                 const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CVHFCalculator(void) : m_mode(VHF_MODE_CLOSE_ONLY) {};
   virtual          ~CVHFCalculator(void) {};

   bool              Init(int period, ENUM_VHF_MODE mode);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &out_vhf[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CVHFCalculator::Init(int period, ENUM_VHF_MODE mode)
  {
   m_period = (period < 1) ? 1 : period;
   m_mode = mode;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CVHFCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &out_vhf[])
  {
   if(rates_total <= m_period)
      return;

   int start_index = (prev_calculated > m_period) ? prev_calculated - 1 : m_period;

// Resize internal buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      if(m_mode == VHF_MODE_HIGH_LOW)
        {
         ArrayResize(m_high, rates_total);
         ArrayResize(m_low, rates_total);
        }
     }

   if(!PrepareData(rates_total, (prev_calculated>0?prev_calculated-1:0), price_type, open, high, low, close))
      return;

   for(int i = start_index; i < rates_total; i++)
     {
      double max_p = -DBL_MAX;
      double min_p = DBL_MAX;
      double sum_change = 0;

      // 1. Numerator (Range)
      if(m_mode == VHF_MODE_CLOSE_ONLY)
        {
         for(int k = 0; k < m_period; k++)
           {
            double p = m_price[i - k];
            if(p > max_p)
               max_p = p;
            if(p < min_p)
               min_p = p;
           }
        }
      else // VHF_MODE_HIGH_LOW
        {
         for(int k = 0; k < m_period; k++)
           {
            int idx = i - k;
            if(m_high[idx] > max_p)
               max_p = m_high[idx];
            if(m_low[idx] < min_p)
               min_p = m_low[idx];
           }
        }

      // 2. Denominator (Noise)
      for(int k = 0; k < m_period; k++)
        {
         int idx = i - k;
         double p_curr = m_price[idx];
         double p_prev = m_price[idx-1];
         sum_change += MathAbs(p_curr - p_prev);
        }

      if(sum_change > 1.0e-9) // Determine VHF
         out_vhf[i] = (max_p - min_p) / sum_change;
      else
         out_vhf[i] = 0.0;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Data (Standard)                                          |
//+------------------------------------------------------------------+
bool CVHFCalculator::PrepareData(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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

      if(m_mode == VHF_MODE_HIGH_LOW)
        {
         m_high[i] = high[i];
         m_low[i]  = low[i];
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CVHFCalculator_HA (Heikin Ashi)             |
//+==================================================================+
class CVHFCalculator_HA : public CVHFCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];
protected:
   virtual bool      PrepareData(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Data (Heikin Ashi)                                       |
//+------------------------------------------------------------------+
bool CVHFCalculator_HA::PrepareData(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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

      if(m_mode == VHF_MODE_HIGH_LOW)
        {
         m_high[i] = m_ha_high[i];
         m_low[i]  = m_ha_low[i];
        }
     }
   return true;
  }

#endif // VHF_CALCULATOR_MQH
//+------------------------------------------------------------------+
