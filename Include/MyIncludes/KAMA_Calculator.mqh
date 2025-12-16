//+------------------------------------------------------------------+
//|                                               KAMA_Calculator.mqh|
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CKamaCalculator (Base Class)                |
//+==================================================================+
class CKamaCalculator
  {
protected:
   int               m_er_period;
   double            m_fastest_sc, m_slowest_sc;

   //--- Persistent Buffer for Incremental Calculation
   double            m_price[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CKamaCalculator(void) {};
   virtual          ~CKamaCalculator(void) {};

   bool              Init(int er_p, int fast_ema_p, int slow_ema_p);
   int               GetPeriod(void) const { return m_er_period; }

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &kama_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CKamaCalculator::Init(int er_p, int fast_ema_p, int slow_ema_p)
  {
   m_er_period = (er_p < 1) ? 1 : er_p;
   m_fastest_sc = 2.0 / ((fast_ema_p < 1 ? 1 : fast_ema_p) + 1.0);
   m_slowest_sc = 2.0 / ((slow_ema_p < 1 ? 1 : slow_ema_p) + 1.0);
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CKamaCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &kama_buffer[])
  {
   if(rates_total <= m_er_period)
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

//--- 4. Calculate KAMA (Incremental Loop)
   int loop_start = MathMax(m_er_period, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      // --- Initialization Step ---
      if(i == m_er_period)
        {
         kama_buffer[i] = m_price[i];
         continue;
        }

      // --- Calculate Efficiency Ratio (ER) ---
      // We need m_price[i - m_er_period], which is safe due to persistent buffer
      double direction = MathAbs(m_price[i] - m_price[i - m_er_period]);
      double volatility = 0;

      for(int j = 0; j < m_er_period; j++)
        {
         volatility += MathAbs(m_price[i - j] - m_price[i - j - 1]);
        }

      double er = (volatility > 0.000001) ? direction / volatility : 0;

      // --- Calculate Scaled Smoothing Constant (SSC) ---
      double sc = pow(er * (m_fastest_sc - m_slowest_sc) + m_slowest_sc, 2);

      // --- Calculate Final AMA ---
      // Recursive calculation uses kama_buffer[i-1] which is persistent (from indicator)
      kama_buffer[i] = kama_buffer[i-1] + sc * (m_price[i] - kama_buffer[i-1]);
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CKamaCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|             CLASS 2: CKamaCalculator_HA (Heikin Ashi)            |
//+==================================================================+
class CKamaCalculator_HA : public CKamaCalculator
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
bool CKamaCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
