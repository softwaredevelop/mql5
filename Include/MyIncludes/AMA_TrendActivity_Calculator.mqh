//+------------------------------------------------------------------+
//|                                 AMA_TrendActivity_Calculator.mqh |
//|  Calculation engine for Standard and Heikin Ashi AMA Activity.   |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CActivityCalculator (Base Class)            |
//|                                                                  |
//+==================================================================+
class CActivityCalculator
  {
protected:
   int               m_ama_period, m_fast_period, m_slow_period, m_atr_period, m_smoothing_period;
   double            m_pi_div_2;

   //--- Internal buffers for source data
   double            m_ama_price[];
   double            m_atr_high[], m_atr_low[], m_atr_close[];

   //--- Virtual method for preparing all necessary source data series.
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

public:
                     CActivityCalculator(void) {};
   virtual          ~CActivityCalculator(void) {};

   //--- Public methods
   bool              Init(int ama_p, int fast_p, int slow_p, int atr_p, int smooth_p);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &activity_buffer[]);
  };

//+------------------------------------------------------------------+
//| CActivityCalculator: Initialization                              |
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
//| CActivityCalculator: Main Calculation Method (Shared Logic)      |
//+------------------------------------------------------------------+
void CActivityCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &activity_buffer[])
  {
   int start_pos = m_ama_period + m_atr_period + m_smoothing_period;
   if(rates_total <= start_pos)
      return;

//--- STEP 1: Prepare all source data (delegated to virtual method)
   if(!PrepareSourceData(rates_total, open, high, low, close, price_type))
      return;

//--- STEP 2: Calculate AMA
   double buffer_ama[];
   ArrayResize(buffer_ama, rates_total);
   double fast_sc = 2.0 / (m_fast_period + 1.0);
   double slow_sc = 2.0 / (m_slow_period + 1.0);
   for(int i = 1; i < rates_total; i++)
     {
      if(i == m_ama_period)
        {
         buffer_ama[i] = m_ama_price[i];
         continue;
        }
      if(i > m_ama_period)
        {
         double direction = MathAbs(m_ama_price[i] - m_ama_price[i - m_ama_period]);
         double volatility = 0;
         for(int j = 0; j < m_ama_period; j++)
            volatility += MathAbs(m_ama_price[i - j] - m_ama_price[i - j - 1]);
         double er = (volatility > 0) ? direction / volatility : 0;
         double ssc = er * (fast_sc - slow_sc) + slow_sc;
         buffer_ama[i] = buffer_ama[i-1] + (ssc*ssc) * (m_ama_price[i] - buffer_ama[i-1]);
        }
     }

//--- STEP 3: Calculate ATR
   double buffer_atr[], tr[];
   ArrayResize(buffer_atr, rates_total);
   ArrayResize(tr, rates_total);
   for(int i = 1; i < rates_total; i++)
      tr[i] = MathMax(m_atr_high[i], m_atr_close[i-1]) - MathMin(m_atr_low[i], m_atr_close[i-1]);
   for(int i = 1; i < rates_total; i++)
     {
      if(i == m_atr_period)
        {
         double sum_tr = 0;
         for(int j = 1; j <= m_atr_period; j++)
            sum_tr += tr[j];
         buffer_atr[i] = sum_tr / m_atr_period;
        }
      else
         if(i > m_atr_period)
            buffer_atr[i] = (buffer_atr[i-1] * (m_atr_period - 1) + tr[i]) / m_atr_period;
     }

//--- STEP 4: Calculate Raw Activity and Scale it using MathArctan
   double scaled_activity[];
   ArrayResize(scaled_activity, rates_total);
   for(int i = m_ama_period + 1; i < rates_total; i++)
     {
      if(buffer_atr[i] > 0)
        {
         double raw_activity = MathAbs(buffer_ama[i] - buffer_ama[i-1]) / buffer_atr[i];
         scaled_activity[i] = MathArctan(raw_activity) / m_pi_div_2;
        }
     }

//--- STEP 5: Calculate Final Oscillator (SMA of Scaled Activity)
   double sum = 0;
   int final_start_pos = m_ama_period + m_smoothing_period;
   for(int i = m_ama_period + 1; i < rates_total; i++)
     {
      sum += scaled_activity[i];
      if(i >= final_start_pos)
        {
         if(i > final_start_pos)
            sum -= scaled_activity[i - m_smoothing_period];
         activity_buffer[i] = sum / m_smoothing_period;
        }
     }
  }

//+------------------------------------------------------------------+
//| CActivityCalculator: Prepares the standard source data series.   |
//+------------------------------------------------------------------+
bool CActivityCalculator::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
//--- Prepare AMA source price
   ArrayResize(m_ama_price, rates_total);
   switch(price_type)
     {
      case PRICE_OPEN:
         ArrayCopy(m_ama_price, open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(m_ama_price, high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(m_ama_price, low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            m_ama_price[i] = (high[i]+low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            m_ama_price[i] = (high[i]+low[i]+close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            m_ama_price[i] = (high[i]+low[i]+2*close[i])/4.0;
         break;
      default:
         ArrayCopy(m_ama_price, close, 0, 0, rates_total);
         break;
     }
//--- Prepare ATR source candles (standard candles)
   ArrayResize(m_atr_high, rates_total);
   ArrayResize(m_atr_low, rates_total);
   ArrayResize(m_atr_close, rates_total);
   ArrayCopy(m_atr_high, high, 0, 0, rates_total);
   ArrayCopy(m_atr_low, low, 0, 0, rates_total);
   ArrayCopy(m_atr_close, close, 0, 0, rates_total);
   return true;
  }

//+==================================================================+
//|                                                                  |
//|           CLASS 2: CActivityCalculator_HA (Heikin Ashi)          |
//|                                                                  |
//+==================================================================+
class CActivityCalculator_HA : public CActivityCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| CActivityCalculator_HA: Prepares the Heikin Ashi source data.    |
//+------------------------------------------------------------------+
bool CActivityCalculator_HA::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
//--- First, calculate the HA candles
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- Prepare AMA source price from HA candles
   ArrayResize(m_ama_price, rates_total);
   switch(price_type)
     {
      case PRICE_OPEN:
         ArrayCopy(m_ama_price, ha_open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(m_ama_price, ha_high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(m_ama_price, ha_low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            m_ama_price[i] = (ha_high[i]+ha_low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            m_ama_price[i] = (ha_high[i]+ha_low[i]+ha_close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            m_ama_price[i] = (ha_high[i]+ha_low[i]+2*ha_close[i])/4.0;
         break;
      default:
         ArrayCopy(m_ama_price, ha_close, 0, 0, rates_total);
         break;
     }
//--- Prepare ATR source candles from HA candles
   ArrayResize(m_atr_high, rates_total);
   ArrayResize(m_atr_low, rates_total);
   ArrayResize(m_atr_close, rates_total);
   ArrayCopy(m_atr_high, ha_high, 0, 0, rates_total);
   ArrayCopy(m_atr_low, ha_low, 0, 0, rates_total);
   ArrayCopy(m_atr_close, ha_close, 0, 0, rates_total);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
