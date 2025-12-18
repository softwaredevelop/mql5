//+------------------------------------------------------------------+
//|                                 AMA_TrendActivity_Calculator.mqh |
//|      VERSION 2.10: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CActivityCalculator (Base Class)            |
//+==================================================================+
class CActivityCalculator
  {
protected:
   int               m_ama_period, m_fast_period, m_slow_period, m_atr_period, m_smoothing_period;
   double            m_pi_div_2;

   //--- Persistent Buffers for Incremental Calculation
   double            m_ama_price[];
   double            m_atr_high[], m_atr_low[], m_atr_close[];

   //--- Intermediate Calculation Buffers (Must persist state)
   double            m_buffer_ama[];
   double            m_buffer_atr[];
   double            m_scaled_activity[];

   //--- Virtual method for preparing source data
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

public:
                     CActivityCalculator(void) {};
   virtual          ~CActivityCalculator(void) {};

   bool              Init(int ama_p, int fast_p, int slow_p, int atr_p, int smooth_p);
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &activity_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CActivityCalculator::Init(int ama_p, int fast_p, int slow_p, int atr_p, int smooth_p)
  {
   m_ama_period       = (ama_p < 1) ? 1 : ama_p;
   m_fast_period      = (fast_p < 1) ? 1 : fast_p;
   m_slow_period      = (slow_p < 1) ? 1 : slow_p;
   m_atr_period       = (atr_p < 1) ? 1 : atr_p;
   m_smoothing_period = (smooth_p < 1) ? 1 : smooth_p;
   m_pi_div_2         = M_PI / 2.0;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CActivityCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &activity_buffer[])
  {
   int start_pos = m_ama_period + m_atr_period + m_smoothing_period;
   if(rates_total <= start_pos)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_ama_price) != rates_total)
     {
      ArrayResize(m_ama_price, rates_total);
      ArrayResize(m_atr_high, rates_total);
      ArrayResize(m_atr_low, rates_total);
      ArrayResize(m_atr_close, rates_total);

      ArrayResize(m_buffer_ama, rates_total);
      ArrayResize(m_buffer_atr, rates_total);
      ArrayResize(m_scaled_activity, rates_total);
     }

//--- 3. Prepare Source Data (Optimized)
   if(!PrepareSourceData(rates_total, start_index, open, high, low, close, price_type))
      return;

//--- 4. Calculate AMA (Incremental)
   double fast_sc = 2.0 / (m_fast_period + 1.0);
   double slow_sc = 2.0 / (m_slow_period + 1.0);

   int loop_start_ama = MathMax(m_ama_period, start_index);

   for(int i = loop_start_ama; i < rates_total; i++)
     {
      if(i == m_ama_period)
        {
         m_buffer_ama[i] = m_ama_price[i];
         continue;
        }

      double direction = MathAbs(m_ama_price[i] - m_ama_price[i - m_ama_period]);
      double volatility = 0;
      for(int j = 0; j < m_ama_period; j++)
         volatility += MathAbs(m_ama_price[i - j] - m_ama_price[i - j - 1]);

      double er = (volatility > 0) ? direction / volatility : 0;
      double ssc = er * (fast_sc - slow_sc) + slow_sc;

      // Recursive AMA using persistent buffer
      m_buffer_ama[i] = m_buffer_ama[i-1] + (ssc*ssc) * (m_ama_price[i] - m_buffer_ama[i-1]);
     }

//--- 5. Calculate ATR (Incremental)
   int loop_start_atr = MathMax(m_atr_period, start_index);

   for(int i = loop_start_atr; i < rates_total; i++)
     {
      double tr = MathMax(m_atr_high[i], m_atr_close[i-1]) - MathMin(m_atr_low[i], m_atr_close[i-1]);

      if(i == m_atr_period)
        {
         double sum_tr = 0;
         for(int k = 0; k < m_atr_period; k++)
           {
            int idx = i - k;
            double t = MathMax(m_atr_high[idx], m_atr_close[idx-1]) - MathMin(m_atr_low[idx], m_atr_close[idx-1]);
            sum_tr += t;
           }
         m_buffer_atr[i] = sum_tr / m_atr_period;
        }
      else
        {
         // RMA (Wilder's Smoothing)
         m_buffer_atr[i] = (m_buffer_atr[i-1] * (m_atr_period - 1) + tr) / m_atr_period;
        }
     }

//--- 6. Calculate Raw Activity and Scale (Incremental)
   int loop_start_act = MathMax(m_ama_period + 1, start_index);

   for(int i = loop_start_act; i < rates_total; i++)
     {
      if(m_buffer_atr[i] > 0)
        {
         double raw_activity = MathAbs(m_buffer_ama[i] - m_buffer_ama[i-1]) / m_buffer_atr[i];
         m_scaled_activity[i] = MathArctan(raw_activity) / m_pi_div_2;
        }
      else
        {
         m_scaled_activity[i] = 0;
        }
     }

//--- 7. Calculate Final SMA (Incremental)
   int final_start_pos = m_ama_period + m_smoothing_period;
   int loop_start_final = MathMax(final_start_pos, start_index);

   for(int i = loop_start_final; i < rates_total; i++)
     {
      double sum = 0;
      for(int j = 0; j < m_smoothing_period; j++)
         sum += m_scaled_activity[i-j];

      activity_buffer[i] = sum / m_smoothing_period;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Source Data (Standard - Optimized)                       |
//+------------------------------------------------------------------+
bool CActivityCalculator::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   for(int i = start_index; i < rates_total; i++)
     {
      // AMA Price
      switch(price_type)
        {
         case PRICE_OPEN:
            m_ama_price[i] = open[i];
            break;
         case PRICE_HIGH:
            m_ama_price[i] = high[i];
            break;
         case PRICE_LOW:
            m_ama_price[i] = low[i];
            break;
         case PRICE_MEDIAN:
            m_ama_price[i] = (high[i]+low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_ama_price[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_ama_price[i] = (high[i]+low[i]+2*close[i])/4.0;
            break;
         default:
            m_ama_price[i] = close[i];
            break;
        }

      // ATR Data
      m_atr_high[i] = high[i];
      m_atr_low[i]  = low[i];
      m_atr_close[i] = close[i];
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CActivityCalculator_HA (Heikin Ashi)        |
//+==================================================================+
class CActivityCalculator_HA : public CActivityCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| Prepare Source Data (Heikin Ashi - Optimized)                    |
//+------------------------------------------------------------------+
bool CActivityCalculator_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
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

   for(int i = start_index; i < rates_total; i++)
     {
      // AMA Price from HA
      switch(price_type)
        {
         case PRICE_OPEN:
            m_ama_price[i] = m_ha_open[i];
            break;
         case PRICE_HIGH:
            m_ama_price[i] = m_ha_high[i];
            break;
         case PRICE_LOW:
            m_ama_price[i] = m_ha_low[i];
            break;
         case PRICE_MEDIAN:
            m_ama_price[i] = (m_ha_high[i]+m_ha_low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_ama_price[i] = (m_ha_high[i]+m_ha_low[i]+m_ha_close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_ama_price[i] = (m_ha_high[i]+m_ha_low[i]+2*m_ha_close[i])/4.0;
            break;
         default:
            m_ama_price[i] = m_ha_close[i];
            break;
        }

      // ATR Data from HA
      m_atr_high[i] = m_ha_high[i];
      m_atr_low[i]  = m_ha_low[i];
      m_atr_close[i] = m_ha_close[i];
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
