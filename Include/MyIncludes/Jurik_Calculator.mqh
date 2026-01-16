//+------------------------------------------------------------------+
//|                                         Jurik_Calculator.mqh     |
//|      High-performance, incremental JMA calculation engine.       |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CJurik_Calculator (Standard)                |
//+==================================================================+
class CJurik_Calculator
  {
protected:
   //--- Parameters
   int               m_length;
   double            m_phase;

   //--- Pre-calculated Constants
   double            m_beta;
   double            m_kv;
   double            m_pow1;
   double            m_pr_phase;

   //--- Internal State Buffers (Persistent)
   double            m_price[];
   double            m_upper_band[];
   double            m_lower_band[];
   double            m_volty[];
   double            m_avg_volty[];
   double            m_rvolty[];
   double            m_alpha[];
   double            m_ma1[];
   double            m_det0[];
   double            m_ma2[];
   double            m_det1[];
   double            m_jma[];

   //--- Virtual Helper for Price Preparation
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE_HA_ALL price_type,
                                        const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CJurik_Calculator(void);
   virtual          ~CJurik_Calculator(void) {};

   bool              Init(int length, double phase);
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE_HA_ALL price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &jma_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CJurik_Calculator::CJurik_Calculator(void) : m_length(0), m_phase(0) {}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CJurik_Calculator::Init(int length, double phase)
  {
   m_length = (length < 1) ? 1 : length;
   m_phase  = phase;

   m_beta = 0.45 * (m_length - 1) / (0.45 * (m_length - 1) + 2);

   double len1 = MathLog(MathSqrt(m_length)) / MathLog(2.0) + 2.0;
   double pow2 = (len1 > 2) ? len1 - 2 : 0.5;
   if(pow2 < 0.5)
      pow2 = 0.5;
   m_kv = MathPow(m_beta, MathSqrt(pow2));

   m_pow1 = pow2;

   m_pr_phase = m_phase / 100.0 + 1.5;
   if(m_phase < -100)
      m_pr_phase = 0.5;
   if(m_phase > 100)
      m_pr_phase = 2.5;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation Method (Incremental O(1))                       |
//+------------------------------------------------------------------+
void CJurik_Calculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE_HA_ALL price_type,
                                  const double &open[], const double &high[], const double &low[], const double &close[],
                                  double &jma_buffer[])
  {
   if(rates_total <= m_length)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- Resize Internal Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_upper_band, rates_total);
      ArrayResize(m_lower_band, rates_total);
      ArrayResize(m_volty, rates_total);
      ArrayResize(m_avg_volty, rates_total);
      ArrayResize(m_rvolty, rates_total);
      ArrayResize(m_alpha, rates_total);
      ArrayResize(m_ma1, rates_total);
      ArrayResize(m_det0, rates_total);
      ArrayResize(m_ma2, rates_total);
      ArrayResize(m_det1, rates_total);
      ArrayResize(m_jma, rates_total);
     }

//--- Prepare Price Data
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- Main Loop
   int loop_start = MathMax(1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      if(i == 0)
        {
         m_upper_band[0] = m_price[0];
         m_lower_band[0] = m_price[0];
         m_volty[0]      = 0;
         m_ma1[0]        = m_price[0];
         m_det0[0]       = 0;
         m_ma2[0]        = m_price[0];
         m_det1[0]       = 0;
         m_jma[0]        = m_price[0];
         jma_buffer[0]   = m_price[0];
         continue;
        }

      double del1 = m_price[i] - m_upper_band[i - 1];
      double del2 = m_price[i] - m_lower_band[i - 1];

      m_upper_band[i] = (del1 > 0) ? m_price[i] : m_price[i] - m_kv * del1;
      m_lower_band[i] = (del2 < 0) ? m_price[i] : m_price[i] - m_kv * del2;

      m_volty[i] = (MathAbs(del1) == MathAbs(del2)) ? 0 : MathMax(MathAbs(del1), MathAbs(del2));

      double volty_sum = 0;
      int start_v = MathMax(0, i - m_length + 1);
      for(int v = start_v; v <= i; v++)
         volty_sum += m_volty[v];

      m_avg_volty[i] = (i >= m_length) ? volty_sum / m_length : 0;

      if(m_avg_volty[i] > 0)
         m_rvolty[i] = m_volty[i] / m_avg_volty[i];
      else
         m_rvolty[i] = 0;

      if(m_rvolty[i] < 1)
         m_rvolty[i] = 1;

      double pow_val = MathPow(m_rvolty[i], m_pow1);
      m_alpha[i] = MathPow(m_beta, pow_val);

      m_ma1[i] = (1 - m_alpha[i]) * m_price[i] + m_alpha[i] * m_ma1[i - 1];
      m_det0[i] = (m_price[i] - m_ma1[i]) * (1 - m_beta) + m_beta * m_det0[i - 1];
      m_ma2[i] = m_ma1[i] + m_pr_phase * m_det0[i];
      m_det1[i] = (m_ma2[i] - m_jma[i - 1]) * MathPow(1 - m_alpha[i], 2) + MathPow(m_alpha[i], 2) * m_det1[i - 1];
      m_jma[i] = m_jma[i - 1] + m_det1[i];

      jma_buffer[i] = m_jma[i];
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price Series (Standard)                                  |
//+------------------------------------------------------------------+
bool CJurik_Calculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE_HA_ALL price_type,
      const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE_STD:
            m_price[i] = close[i];
            break;
         case PRICE_OPEN_STD:
            m_price[i] = open[i];
            break;
         case PRICE_HIGH_STD:
            m_price[i] = high[i];
            break;
         case PRICE_LOW_STD:
            m_price[i] = low[i];
            break;
         case PRICE_MEDIAN_STD:
            m_price[i] = (high[i] + low[i]) / 2.0;
            break;
         case PRICE_TYPICAL_STD:
            m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED_STD:
            m_price[i] = (high[i] + low[i] + 2 * close[i]) / 4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CJurik_Calculator_HA (Heikin Ashi)          |
//+==================================================================+
class CJurik_Calculator_HA : public CJurik_Calculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE_HA_ALL price_type,
                                        const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price Series (Heikin Ashi)                               |
//+------------------------------------------------------------------+
bool CJurik_Calculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE_HA_ALL price_type,
      const double &open[], const double &high[], const double &low[], const double &close[])
  {
// 1. Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

// 2. Calculate HA Candles (Incremental)
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

// 3. Fill m_price from HA data based on specific HA price type
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_HA_CLOSE:
            m_price[i] = m_ha_close[i];
            break;
         case PRICE_HA_OPEN:
            m_price[i] = m_ha_open[i];
            break;
         case PRICE_HA_HIGH:
            m_price[i] = m_ha_high[i];
            break;
         case PRICE_HA_LOW:
            m_price[i] = m_ha_low[i];
            break;
         case PRICE_HA_MEDIAN:
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
            break;
         case PRICE_HA_TYPICAL:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
            break;
         case PRICE_HA_WEIGHTED:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2 * m_ha_close[i]) / 4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break; // Default to HA Close
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
