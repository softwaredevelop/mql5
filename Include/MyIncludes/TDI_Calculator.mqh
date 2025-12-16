//+------------------------------------------------------------------+
//|                                               TDI_Calculator.mqh |
//|      VERSION 2.01: Fixed override signature mismatch.            |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CTDICalculator (Base Class)                 |
//+==================================================================+
class CTDICalculator
  {
protected:
   int               m_rsi_period, m_price_period, m_signal_period, m_base_period;
   double            m_std_dev;

   //--- Persistent Buffers
   double            m_price[];
   double            m_rsi_buffer[];

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CTDICalculator(void) {};
   virtual          ~CTDICalculator(void) {};

   bool              Init(int rsi_p, int price_p, int signal_p, int base_p, double dev);
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &price_line_out[], double &signal_line_out[], double &base_line_out[],
                               double &upper_band_out[], double &lower_band_out[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CTDICalculator::Init(int rsi_p, int price_p, int signal_p, int base_p, double dev)
  {
   m_rsi_period    = (rsi_p < 1) ? 1 : rsi_p;
   m_price_period  = (price_p < 1) ? 1 : price_p;
   m_signal_period = (signal_p < 1) ? 1 : signal_p;
   m_base_period   = (base_p < 1) ? 1 : base_p;
   m_std_dev       = (dev <= 0) ? 1.618 : dev;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CTDICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &price_line_out[], double &signal_line_out[], double &base_line_out[],
                               double &upper_band_out[], double &lower_band_out[])
  {
   if(rates_total <= m_rsi_period + m_base_period)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_rsi_buffer, rates_total);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// RSI Loop
   double sum_pos = 0, sum_neg = 0;
   for(int i = 1; i < rates_total; i++)
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

// Price Line
   int pl_start = m_rsi_period + m_price_period - 2;
   int loop_start_pl = MathMax(pl_start, start_index);
   for(int i = loop_start_pl; i < rates_total; i++)
     {
      double sum=0;
      for(int j=0; j<m_price_period; j++)
         sum+=m_rsi_buffer[i-j];
      price_line_out[i]=sum/m_price_period;
     }

// Signal Line
   int sl_start = pl_start + m_signal_period - 1;
   int loop_start_sl = MathMax(sl_start, start_index);
   for(int i = loop_start_sl; i < rates_total; i++)
     {
      double sum=0;
      for(int j=0; j<m_signal_period; j++)
         sum+=price_line_out[i-j];
      signal_line_out[i]=sum/m_signal_period;
     }

// Base Line
   int bl_start = pl_start + m_base_period - 1;
   int loop_start_bl = MathMax(bl_start, start_index);
   for(int i = loop_start_bl; i < rates_total; i++)
     {
      double sum=0;
      for(int j=0; j<m_base_period; j++)
         sum+=price_line_out[i-j];
      base_line_out[i]=sum/m_base_period;
     }

// Bands
   int bands_start = m_rsi_period + m_base_period - 2;
   int loop_start_bands = MathMax(bands_start, start_index);
   for(int i = loop_start_bands; i < rates_total; i++)
     {
      double rsi_ma = 0;
      double sum_rsi = 0;
      for(int j=0; j<m_base_period; j++)
         sum_rsi += m_rsi_buffer[i-j];
      rsi_ma = sum_rsi / m_base_period;

      double sum_sq = 0;
      for(int j = 0; j < m_base_period; j++)
         sum_sq += MathPow(m_rsi_buffer[i-j] - rsi_ma, 2);

      double std_dev = MathSqrt(sum_sq / m_base_period);

      upper_band_out[i] = base_line_out[i] + m_std_dev * std_dev;
      lower_band_out[i] = base_line_out[i] - m_std_dev * std_dev;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard)                                         |
//+------------------------------------------------------------------+
bool CTDICalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|             CLASS 2: CTDICalculator_HA (Heikin Ashi)             |
//+==================================================================+
class CTDICalculator_HA : public CTDICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   // FIX: Added 'price_type' to match base class signature
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi)                                      |
//+------------------------------------------------------------------+
bool CTDICalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
