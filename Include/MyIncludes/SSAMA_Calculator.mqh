//+------------------------------------------------------------------+
//|                                          SSAMA_Calculator.mqh    |
//|      SuperSmoother Adaptive Moving Average Engine.               |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|           CLASS 1: CSSAMACalculator (Base Class)                 |
//+==================================================================+
class CSSAMACalculator
  {
protected:
   int               m_er_period;
   int               m_min_period;
   int               m_max_period;

   //--- Persistent Buffers
   double            m_price[];
   double            m_ssama_buf[]; // Internal buffer for recursive calc

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CSSAMACalculator(void) {};
   virtual          ~CSSAMACalculator(void) {};

   bool              Init(int er_p, int min_p, int max_p);

   //--- Main Calculation
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &ssama_out[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CSSAMACalculator::Init(int er_p, int min_p, int max_p)
  {
   m_er_period = (er_p < 1) ? 1 : er_p;
   m_min_period = (min_p < 2) ? 2 : min_p; // SS needs at least 2
   m_max_period = (max_p <= m_min_period) ? m_min_period + 1 : max_p;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CSSAMACalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                 double &ssama_out[])
  {
   if(rates_total <= m_er_period + 2)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_ssama_buf, rates_total);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// Main Loop
   int loop_start = MathMax(m_er_period, start_index);

// Initialization
   if(loop_start == m_er_period)
     {
      // Seed with price to avoid startup transient
      m_ssama_buf[loop_start-1] = m_price[loop_start-1];
      m_ssama_buf[loop_start-2] = m_price[loop_start-2];
      ssama_out[loop_start-1] = m_price[loop_start-1];
      ssama_out[loop_start-2] = m_price[loop_start-2];
     }

   for(int i = loop_start; i < rates_total; i++)
     {
      // 1. Calculate Efficiency Ratio (ER)
      double direction = MathAbs(m_price[i] - m_price[i - m_er_period]);
      double volatility = 0;
      for(int j = 0; j < m_er_period; j++)
         volatility += MathAbs(m_price[i - j] - m_price[i - j - 1]);

      double er = (volatility > 0.000001) ? direction / volatility : 0;

      // 2. Calculate Adaptive Period
      // High ER (1.0) -> Min Period (Fast)
      // Low ER (0.0) -> Max Period (Slow)
      double current_period = m_min_period + (1.0 - er) * (m_max_period - m_min_period);

      // 3. Calculate SuperSmoother Coefficients dynamically
      double a1 = exp(-M_SQRT2 * M_PI / current_period);
      double b1 = 2.0 * a1 * cos(M_SQRT2 * M_PI / current_period);
      double c2 = b1;
      double c3 = -a1 * a1;
      double c1 = 1.0 - c2 - c3;

      // 4. Calculate SSAMA
      // SS[i] = c1*(P[i] + P[i-1])/2 + c2*SS[i-1] + c3*SS[i-2]
      m_ssama_buf[i] = c1 * (m_price[i] + m_price[i-1]) / 2.0 + c2 * m_ssama_buf[i-1] + c3 * m_ssama_buf[i-2];

      ssama_out[i] = m_ssama_buf[i];
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard)                                         |
//+------------------------------------------------------------------+
bool CSSAMACalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|           CLASS 2: CSSAMACalculator_HA (Heikin Ashi)             |
//+==================================================================+
class CSSAMACalculator_HA : public CSSAMACalculator
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
bool CSSAMACalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
