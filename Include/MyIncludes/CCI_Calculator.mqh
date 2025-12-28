//+------------------------------------------------------------------+
//|                                               CCI_Calculator.mqh |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|             CLASS 1: CCCI_Calculator (Base Class)                |
//+==================================================================+
class CCCI_Calculator
  {
protected:
   int               m_cci_period, m_bands_period;
   double            m_bands_dev;

   //--- Engine for Signal Line
   CMovingAverageCalculator m_signal_engine;

   //--- Persistent Buffers
   double            m_price[];
   double            m_sma_buffer[]; // Simple Moving Average of Price
   double            m_mad_buffer[]; // Mean Absolute Deviation

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CCCI_Calculator(void) {};
   virtual          ~CCCI_Calculator(void) {};

   //--- Init now takes ENUM_MA_TYPE
   bool              Init(int cci_p, int ma_p, ENUM_MA_TYPE ma_m, int bands_p, double bands_dev);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &cci_out[], double &signal_out[], double &upper_out[], double &lower_out[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CCCI_Calculator::Init(int cci_p, int ma_p, ENUM_MA_TYPE ma_m, int bands_p, double bands_dev)
  {
   m_cci_period   = (cci_p < 1) ? 1 : cci_p;
   m_bands_period = (bands_p < 1) ? 1 : bands_p;
   m_bands_dev    = (bands_dev <= 0) ? 2.0 : bands_dev;

// Initialize Signal Engine
   if(!m_signal_engine.Init(ma_p, ma_m))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CCCI_Calculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                double &cci_out[], double &signal_out[], double &upper_out[], double &lower_out[])
  {
// Minimum bars check
   if(rates_total <= m_cci_period + m_bands_period)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_sma_buffer, rates_total);
      ArrayResize(m_mad_buffer, rates_total);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   const double CCI_CONSTANT = 0.015;

//--- 1. Calculate SMA of Price (Incremental)
// We can use a sliding window sum for O(1) SMA calculation, but standard loop is safer for now.
// Optimization: Only calculate for new bars.
   int loop_start_sma = MathMax(m_cci_period - 1, start_index);

   for(int i = loop_start_sma; i < rates_total; i++)
     {
      double sum = 0;
      for(int j = 0; j < m_cci_period; j++)
         sum += m_price[i-j];
      m_sma_buffer[i] = sum / m_cci_period;
     }

//--- 2. Calculate Mean Absolute Deviation (MAD)
   for(int i = loop_start_sma; i < rates_total; i++)
     {
      double deviation_sum = 0;
      for(int j = 0; j < m_cci_period; j++)
         deviation_sum += MathAbs(m_price[i - j] - m_sma_buffer[i]);
      m_mad_buffer[i] = deviation_sum / m_cci_period;
     }

//--- 3. Calculate CCI
   if(prev_calculated == 0)
      ArrayInitialize(cci_out, EMPTY_VALUE);

   for(int i = loop_start_sma; i < rates_total; i++)
     {
      if(m_mad_buffer[i] > 0)
         cci_out[i] = (m_price[i] - m_sma_buffer[i]) / (CCI_CONSTANT * m_mad_buffer[i]);
      else
         cci_out[i] = 0;
     }

//--- 4. Calculate Signal Line (Using Engine)
// CCI is valid from index: m_cci_period - 1
   int cci_offset = m_cci_period - 1;
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, cci_out, signal_out, cci_offset);

//--- 5. Calculate Bollinger Bands (Optimized)
// Bands are based on CCI and centered on Signal Line
   int ma_period = m_signal_engine.GetPeriod();
   int bands_start_pos = cci_offset + ma_period - 1; // Where signal line starts
   int loop_start_bands = MathMax(bands_start_pos, start_index);

   if(prev_calculated == 0)
     {
      ArrayInitialize(upper_out, EMPTY_VALUE);
      ArrayInitialize(lower_out, EMPTY_VALUE);
     }

   for(int i = loop_start_bands; i < rates_total; i++)
     {
      if(signal_out[i] == EMPTY_VALUE)
         continue;

      double std_dev = 0, sum_sq = 0;
      // Standard Deviation of CCI around the Signal Line
      for(int j = 0; j < m_bands_period; j++)
         sum_sq += MathPow(cci_out[i-j] - signal_out[i], 2);

      std_dev = MathSqrt(sum_sq / m_bands_period);
      upper_out[i] = signal_out[i] + m_bands_dev * std_dev;
      lower_out[i] = signal_out[i] - m_bands_dev * std_dev;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CCCI_Calculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|             CLASS 2: CCCI_Calculator_HA (Heikin Ashi)            |
//+==================================================================+
class CCCI_Calculator_HA : public CCCI_Calculator
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
bool CCCI_Calculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
