//+------------------------------------------------------------------+
//|                                           RSI_Pro_Calculator.mqh |
//|        VERSION 3.10: Fixed RSI Drift (Added internal buffers).   |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|             CLASS 1: CRSIProCalculator (Base Class)              |
//+==================================================================+
class CRSIProCalculator
  {
protected:
   int               m_rsi_period;
   int               m_ma_period;
   double            m_deviation;

   //--- Engine for Signal Line
   CMovingAverageCalculator m_ma_engine;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];
   double            m_rsi_buffer[];
   double            m_ma_buffer[];
   double            m_upper_band[];
   double            m_lower_band[];

   //--- NEW: Persistent Buffers for Wilder's Smoothing (Fixes Drift)
   double            m_avg_gain[];
   double            m_avg_loss[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CRSIProCalculator(void);
   virtual          ~CRSIProCalculator(void) {};

   //--- Init now takes ENUM_MA_TYPE
   bool              Init(int rsi_p, int ma_p, ENUM_MA_TYPE ma_m, double dev);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &rsi_out[], double &ma_out[], double &upper_out[], double &lower_out[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRSIProCalculator::CRSIProCalculator(void)
  {
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CRSIProCalculator::Init(int rsi_p, int ma_p, ENUM_MA_TYPE ma_m, double dev)
  {
   m_rsi_period = (rsi_p < 1) ? 1 : rsi_p;
   m_ma_period = (ma_p < 1) ? 1 : ma_p;
   m_deviation = dev;

// Initialize MA Engine
   if(!m_ma_engine.Init(m_ma_period, ma_m))
      return false;

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
      start_index = 0;
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

      // Resize internal averaging buffers
      ArrayResize(m_avg_gain, rates_total);
      ArrayResize(m_avg_loss, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Calculate RSI (Incremental)
   int i = start_index;
   if(i == 0)
     {
      m_avg_gain[0] = 0;
      m_avg_loss[0] = 0;
      m_rsi_buffer[0] = 0;
      i = 1;
     }

   for(; i < rates_total; i++)
     {
      double diff = m_price[i] - m_price[i-1];
      double pos = (diff > 0 ? diff : 0);
      double neg = (diff < 0 ? -diff : 0);

      if(i <= m_rsi_period)
        {
         // First value (at index period) is SMA.
         // Subsequent values are RMA.
         if(i < m_rsi_period)
           {
            // Accumulate
            m_avg_gain[i] = m_avg_gain[i-1] + pos;
            m_avg_loss[i] = m_avg_loss[i-1] + neg;
            m_rsi_buffer[i] = 0;
           }
         else // i == m_rsi_period
           {
            // Calculate initial SMA
            // Add current value to sum
            double sum_g = m_avg_gain[i-1] + pos;
            double sum_l = m_avg_loss[i-1] + neg;

            m_avg_gain[i] = sum_g / m_rsi_period;
            m_avg_loss[i] = sum_l / m_rsi_period;

            if(m_avg_loss[i] > 0)
               m_rsi_buffer[i] = 100.0 - (100.0 / (1.0 + (m_avg_gain[i] / m_avg_loss[i])));
            else
               m_rsi_buffer[i] = 100.0;
           }
        }
      else
        {
         // Normal Phase: Wilder's Smoothing (RMA)
         // Avg[i] = (Avg[i-1] * (N-1) + Val[i]) / N
         // We use the persistent buffer values from [i-1], which are stable!

         m_avg_gain[i] = (m_avg_gain[i-1] * (m_rsi_period - 1) + pos) / m_rsi_period;
         m_avg_loss[i] = (m_avg_loss[i-1] * (m_rsi_period - 1) + neg) / m_rsi_period;

         if(m_avg_loss[i] > 0)
            m_rsi_buffer[i] = 100.0 - (100.0 / (1.0 + (m_avg_gain[i] / m_avg_loss[i])));
         else
            m_rsi_buffer[i] = 100.0;
        }
     }

//--- 5. Calculate Moving Average on RSI (Using Engine)
// RSI is valid from index: m_rsi_period
   int rsi_offset = m_rsi_period;
   m_ma_engine.CalculateOnArray(rates_total, prev_calculated, m_rsi_buffer, m_ma_buffer, rsi_offset);

//--- 6. Calculate Bollinger Bands (Optimized)
// Bands are based on the MA, so they start where MA starts
   int ma_start_pos = rsi_offset + m_ma_period - 1;
   int loop_start_bands = MathMax(ma_start_pos, start_index);

   for(i = loop_start_bands; i < rates_total; i++)
     {
      double std_dev_val = 0, sum_sq = 0;
      for(int j = 0; j < m_ma_period; j++)
         sum_sq += pow(m_rsi_buffer[i-j] - m_ma_buffer[i], 2);
      std_dev_val = sqrt(sum_sq / m_ma_period);

      m_upper_band[i] = m_ma_buffer[i] + m_deviation * std_dev_val;
      m_lower_band[i] = m_ma_buffer[i] - m_deviation * std_dev_val;
     }

//--- 7. Copy to Output
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
//|             CLASS 2: CRSIProCalculator_HA (Heikin Ashi)          |
//+==================================================================+
class CRSIProCalculator_HA : public CRSIProCalculator
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
bool CRSIProCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
