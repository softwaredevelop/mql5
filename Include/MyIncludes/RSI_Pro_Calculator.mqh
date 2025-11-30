//+------------------------------------------------------------------+
//|                                           RSI_Pro_Calculator.mqh |
//|        Calculation engine for Standard and Heikin Ashi RSI Pro.  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CRSIProCalculator (Base Class)              |
//+==================================================================+
class CRSIProCalculator
  {
protected:
   int               m_rsi_period;
   int               m_ma_period;
   double            m_deviation;
   ENUM_MA_METHOD    m_ma_method;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];
   double            m_rsi_buffer[];
   double            m_ma_buffer[];
   double            m_upper_band[];
   double            m_lower_band[];

   //--- Persistent State for Wilder's Smoothing
   double            m_sum_pos;
   double            m_sum_neg;

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CRSIProCalculator(void);
   virtual          ~CRSIProCalculator(void) {};

   bool              Init(int rsi_p, int ma_p, ENUM_MA_METHOD ma_m, double dev);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &rsi_out[], double &ma_out[], double &upper_out[], double &lower_out[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRSIProCalculator::CRSIProCalculator(void) : m_sum_pos(0), m_sum_neg(0)
  {
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CRSIProCalculator::Init(int rsi_p, int ma_p, ENUM_MA_METHOD ma_m, double dev)
  {
   m_rsi_period = (rsi_p < 1) ? 1 : rsi_p;
   m_ma_period = (ma_p < 1) ? 1 : ma_p;
   m_ma_method = ma_m;
   m_deviation = dev;
   m_sum_pos = 0;
   m_sum_neg = 0;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CRSIProCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                  double &rsi_out[], double &ma_out[], double &upper_out[], double &lower_out[])
  {
   if(rates_total <= m_rsi_period)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
     {
      start_index = 0;
      m_sum_pos = 0;
      m_sum_neg = 0;
     }
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_rsi_buffer, rates_total);
      ArrayResize(m_ma_buffer, rates_total);
      ArrayResize(m_upper_band, rates_total);
      ArrayResize(m_lower_band, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Calculate RSI (Incremental)
   int i = start_index;
   if(i == 0)
      i = 1; // Skip first bar for diff

   for(; i < rates_total; i++)
     {
      double diff = m_price[i] - m_price[i-1];
     }

// Reset sums for full loop
   double sum_pos = 0;
   double sum_neg = 0;

   for(i = 1; i < rates_total; i++)
     {
      double diff = m_price[i] - m_price[i-1];
      sum_pos = (sum_pos * (m_rsi_period - 1) + (diff > 0 ? diff : 0)) / m_rsi_period;
      sum_neg = (sum_neg * (m_rsi_period - 1) + (diff < 0 ? -diff : 0)) / m_rsi_period;

      if(i >= m_rsi_period)
        {
         if(sum_neg > 0)
            m_rsi_buffer[i] = 100.0 - (100.0 / (1.0 + (sum_pos / sum_neg)));
         else
            m_rsi_buffer[i] = 100.0;
        }
      else
         m_rsi_buffer[i] = 0;
     }

//--- 5. Calculate Moving Average on RSI (Optimized)
   int ma_start_pos = m_rsi_period + m_ma_period - 1;
   int loop_start_ma = MathMax(ma_start_pos, start_index);

   for(i = loop_start_ma; i < rates_total; i++)
     {
      switch(m_ma_method)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == ma_start_pos)
              {
               double sum = 0;
               for(int j = 0; j < m_ma_period; j++)
                  sum += m_rsi_buffer[i-j];
               m_ma_buffer[i] = sum / m_ma_period;
              }
            else
              {
               if(m_ma_method == MODE_EMA)
                 {
                  double pr = 2.0 / (m_ma_period + 1.0);
                  m_ma_buffer[i] = m_rsi_buffer[i] * pr + m_ma_buffer[i-1] * (1.0 - pr);
                 }
               else
                  m_ma_buffer[i] = (m_ma_buffer[i-1] * (m_ma_period - 1) + m_rsi_buffer[i]) / m_ma_period;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum = 0, weight_sum = 0;
            for(int j = 0; j < m_ma_period; j++)
              {
               int weight = m_ma_period - j;
               lwma_sum += m_rsi_buffer[i-j] * weight;
               weight_sum += weight;
              }
            if(weight_sum > 0)
               m_ma_buffer[i] = lwma_sum / weight_sum;
            break;
           }
         default: // MODE_SMA
           {
            double sum = 0;
            for(int j = 0; j < m_ma_period; j++)
               sum += m_rsi_buffer[i-j];
            m_ma_buffer[i] = sum / m_ma_period;
            break;
           }
        }
     }

//--- 6. Calculate Bollinger Bands (Optimized)
   for(i = loop_start_ma; i < rates_total; i++)
     {
      double std_dev_val = 0, sum_sq = 0;
      for(int j = 0; j < m_ma_period; j++)
         sum_sq += pow(m_rsi_buffer[i-j] - m_ma_buffer[i], 2);
      std_dev_val = sqrt(sum_sq / m_ma_period);

      m_upper_band[i] = m_ma_buffer[i] + m_deviation * std_dev_val;
      m_lower_band[i] = m_ma_buffer[i] - m_deviation * std_dev_val;
     }

//--- 7. Copy to Output
// We copy everything to be safe, ArrayCopy is fast
   ArrayCopy(rsi_out, m_rsi_buffer, 0, 0, rates_total);
   ArrayCopy(ma_out, m_ma_buffer, 0, 0, rates_total);
   ArrayCopy(upper_out, m_upper_band, 0, 0, rates_total);
   ArrayCopy(lower_out, m_lower_band, 0, 0, rates_total);
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CRSIProCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (high[i]+low[i]+close[i]+close[i])/4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CRSIProCalculator_HA (Heikin Ashi)          |
//+==================================================================+
class CRSIProCalculator_HA : public CRSIProCalculator
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
bool CRSIProCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
