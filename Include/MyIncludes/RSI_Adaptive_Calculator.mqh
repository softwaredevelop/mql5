//+------------------------------------------------------------------+
//|                                     RSI_Adaptive_Calculator.mqh  |
//|      Engine for a variable-length RSI (Dynamic Momentum Index).  |
//|      VERSION 4.00: Optimized price preparation logic.            |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

enum ENUM_ADAPTIVE_SOURCE_RSI
  {
   ADAPTIVE_SOURCE_RSI_STANDARD,    // Calculate Volatility on Standard Price
   ADAPTIVE_SOURCE_RSI_HEIKIN_ASHI  // Calculate Volatility on Heikin Ashi Price
  };

//+==================================================================+
//|             CLASS 1: CAdaptiveRSICalculator (Base Class)         |
//+==================================================================+
class CAdaptiveRSICalculator
  {
protected:
   int               m_pivotal_period, m_vola_short, m_vola_long;
   ENUM_ADAPTIVE_SOURCE_RSI m_adaptive_source;

   //--- Persistent Buffers (Non-Series)
   double            m_price[];      // Used for Volatility calculation
   double            m_rsi_source[]; // Used for RSI calculation
   double            m_vola_sum[];
   double            m_vola_avg[];
   double            m_nsp_buffer[];

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CAdaptiveRSICalculator(void) {};
   virtual          ~CAdaptiveRSICalculator(void) {};

   bool              Init(int pivotal_p, int vola_s, int vola_l, ENUM_ADAPTIVE_SOURCE_RSI adapt_src);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &rsi_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CAdaptiveRSICalculator::Init(int pivotal_p, int vola_s, int vola_l, ENUM_ADAPTIVE_SOURCE_RSI adapt_src)
  {
   m_pivotal_period = (pivotal_p < 2) ? 2 : pivotal_p;
   m_vola_short = (vola_s < 1) ? 1 : vola_s;
   m_vola_long = (vola_l <= m_vola_short) ? m_vola_short + 1 : vola_l;
   m_adaptive_source = adapt_src;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CAdaptiveRSICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                       double &rsi_buffer[])
  {
// Safety Check
   if(rates_total <= m_vola_long + m_pivotal_period * 2)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_rsi_source, rates_total);
      ArrayResize(m_vola_sum, rates_total);
      ArrayResize(m_vola_avg, rates_total);
      ArrayResize(m_nsp_buffer, rates_total);
     }

   if(ArraySize(rsi_buffer) != rates_total)
      ArrayResize(rsi_buffer, rates_total);

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 1. Calculate Volatility Sum (Incremental)
   int loop_start_vola = MathMax(m_vola_short, start_index);

   for(int i = loop_start_vola; i < rates_total; i++)
     {
      double sum = 0;
      for(int j = 0; j < m_vola_short; j++)
         sum += MathAbs(m_price[i-j] - m_price[i-j-1]);
      m_vola_sum[i] = sum;
     }

//--- 2. Calculate Volatility Avg and Adaptive Period (NSP)
   int loop_start_nsp = MathMax(m_vola_short + m_vola_long - 1, start_index);

   for(int i = loop_start_nsp; i < rates_total; i++)
     {
      double sum_of_sums = 0;
      for(int j = 0; j < m_vola_long; j++)
         sum_of_sums += m_vola_sum[i-j];
      m_vola_avg[i] = sum_of_sums / m_vola_long;

      double vola_ratio = (m_vola_avg[i] > 0.000001) ? m_vola_sum[i] / m_vola_avg[i] : 1.0;

      // Calculate adaptive period
      int period = (int)round(m_pivotal_period / vola_ratio);

      // Clamp period
      m_nsp_buffer[i] = fmax(2, fmin(m_pivotal_period * 2, period));
     }

//--- 3. Calculate Simple RSI using m_rsi_source
   int loop_start_rsi = MathMax(m_vola_short + m_vola_long, start_index);

   for(int i = loop_start_rsi; i < rates_total; i++)
     {
      int current_nsp = (int)m_nsp_buffer[i];

      if(i <= current_nsp)
        {
         rsi_buffer[i] = 50.0;
         continue;
        }

      double sum_pos = 0, sum_neg = 0;

      // Brute force loop (Simple RSI logic)
      for(int j = 0; j < current_nsp; j++)
        {
         double diff = m_rsi_source[i-j] - m_rsi_source[i-j-1];
         if(diff > 0)
            sum_pos += diff;
         else
            sum_neg -= diff;
        }

      if(sum_pos + sum_neg > 0.000001)
         rsi_buffer[i] = 100.0 * sum_pos / (sum_pos + sum_neg);
      else
         rsi_buffer[i] = 50.0;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard)                                         |
//+------------------------------------------------------------------+
bool CAdaptiveRSICalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      double p;
      switch(price_type)
        {
         case PRICE_CLOSE:
            p = close[i];
            break;
         case PRICE_OPEN:
            p = open[i];
            break;
         case PRICE_HIGH:
            p = high[i];
            break;
         case PRICE_LOW:
            p = low[i];
            break;
         case PRICE_MEDIAN:
            p = (high[i]+low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            p = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            p = (high[i]+low[i]+2*close[i])/4.0;
            break;
         default:
            p = close[i];
            break;
        }
      m_price[i] = p;      // Volatility Source
      m_rsi_source[i] = p; // RSI Source
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CAdaptiveRSICalculator_HA                   |
//+==================================================================+
class CAdaptiveRSICalculator_HA : public CAdaptiveRSICalculator
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
bool CAdaptiveRSICalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
      // 1. Calculate HA Price for RSI Source
      double ha_p;
      switch(price_type)
        {
         case PRICE_CLOSE:
            ha_p = m_ha_close[i];
            break;
         case PRICE_OPEN:
            ha_p = m_ha_open[i];
            break;
         case PRICE_HIGH:
            ha_p = m_ha_high[i];
            break;
         case PRICE_LOW:
            ha_p = m_ha_low[i];
            break;
         case PRICE_MEDIAN:
            ha_p = (m_ha_high[i]+m_ha_low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            ha_p = (m_ha_high[i]+m_ha_low[i]+m_ha_close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            ha_p = (m_ha_high[i]+m_ha_low[i]+2*m_ha_close[i])/4.0;
            break;
         default:
            ha_p = m_ha_close[i];
            break;
        }
      m_rsi_source[i] = ha_p;

      // 2. Calculate Price for Volatility (ER)
      if(m_adaptive_source == ADAPTIVE_SOURCE_RSI_HEIKIN_ASHI)
        {
         m_price[i] = ha_p;
        }
      else // ADAPTIVE_SOURCE_RSI_STANDARD
        {
         double std_p;
         switch(price_type)
           {
            case PRICE_CLOSE:
               std_p = close[i];
               break;
            case PRICE_OPEN:
               std_p = open[i];
               break;
            case PRICE_HIGH:
               std_p = high[i];
               break;
            case PRICE_LOW:
               std_p = low[i];
               break;
            case PRICE_MEDIAN:
               std_p = (high[i]+low[i])/2.0;
               break;
            case PRICE_TYPICAL:
               std_p = (high[i]+low[i]+close[i])/3.0;
               break;
            case PRICE_WEIGHTED:
               std_p = (high[i]+low[i]+2*close[i])/4.0;
               break;
            default:
               std_p = close[i];
               break;
           }
         m_price[i] = std_p;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
