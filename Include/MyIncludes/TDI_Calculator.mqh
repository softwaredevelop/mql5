//+------------------------------------------------------------------+
//|                                               TDI_Calculator.mqh |
//|        Calculation engine for Standard and Heikin Ashi TDI.      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CTDICalculator (Standard)                   |
//|                                                                  |
//+==================================================================+
class CTDICalculator
  {
protected:
   int               m_rsi_period;
   int               m_price_period;
   int               m_signal_period;
   int               m_base_period;
   double            m_std_dev;

   double            m_price[];
   double            m_rsi_buffer[];
   double            m_price_line[];
   double            m_signal_line[];
   double            m_base_line[];
   double            m_upper_band[];
   double            m_lower_band[];

   double            CalculateSMA(int position, int period, const double &source_buffer[]);
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CTDICalculator(void) {};
   virtual          ~CTDICalculator(void) {};

   bool              Init(int rsi_p, int price_p, int signal_p, int base_p, double dev);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                  double &price_line_out[], double &signal_line_out[], double &base_line_out[],
                  double &upper_band_out[], double &lower_band_out[]);
  };

//+------------------------------------------------------------------+
//| CTDICalculator: Initialization                                   |
//+------------------------------------------------------------------+
bool CTDICalculator::Init(int rsi_p, int price_p, int signal_p, int base_p, double dev)
  {
   m_rsi_period = (rsi_p < 1) ? 1 : rsi_p;
   m_price_period = (price_p < 1) ? 1 : price_p;
   m_signal_period = (signal_p < 1) ? 1 : signal_p;
   m_base_period = (base_p < 1) ? 1 : base_p;
   m_std_dev = (dev <= 0) ? 1.618 : dev;
   return true;
  }

//+------------------------------------------------------------------+
//| CTDICalculator: Main Calculation Method                          |
//+------------------------------------------------------------------+
void CTDICalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &price_line_out[], double &signal_line_out[], double &base_line_out[],
                               double &upper_band_out[], double &lower_band_out[])
  {
   if(rates_total <= m_rsi_period)
      return;

   ArrayResize(m_price, rates_total);
   ArrayResize(m_rsi_buffer, rates_total);
   ArrayResize(m_price_line, rates_total);
   ArrayResize(m_signal_line, rates_total);
   ArrayResize(m_base_line, rates_total);
   ArrayResize(m_upper_band, rates_total);
   ArrayResize(m_lower_band, rates_total);

   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   double sum_pos = 0, sum_neg = 0;
   for(int i = 1; i < rates_total; i++)
     {
      double diff = m_price[i] - m_price[i-1];
      sum_pos = (sum_pos * (m_rsi_period - 1) + (diff > 0 ? diff : 0)) / m_rsi_period;
      sum_neg = (sum_neg * (m_rsi_period - 1) + (diff < 0 ? -diff : 0)) / m_rsi_period;

      if(i > m_rsi_period)
        {
         if(sum_neg > 0)
            m_rsi_buffer[i] = 100.0 - (100.0 / (1.0 + (sum_pos / sum_neg)));
         else
            m_rsi_buffer[i] = 100.0;
        }
     }

   for(int i = m_rsi_period + m_price_period; i < rates_total; i++)
      m_price_line[i] = CalculateSMA(i, m_price_period, m_rsi_buffer);

   for(int i = m_rsi_period + m_price_period + m_signal_period; i < rates_total; i++)
      m_signal_line[i] = CalculateSMA(i, m_signal_period, m_price_line);

   for(int i = m_rsi_period + m_price_period + m_base_period; i < rates_total; i++)
      m_base_line[i] = CalculateSMA(i, m_base_period, m_price_line);

   for(int i = m_rsi_period + m_price_period + m_base_period; i < rates_total; i++)
     {
      double std_dev_val = 0, sum_sq = 0;
      for(int j = 0; j < m_base_period; j++)
         sum_sq += pow(m_price_line[i-j] - m_base_line[i], 2);
      std_dev_val = sqrt(sum_sq / m_base_period);

      m_upper_band[i] = m_base_line[i] + m_std_dev * std_dev_val;
      m_lower_band[i] = m_base_line[i] - m_std_dev * std_dev_val;
     }

   ArrayCopy(price_line_out, m_price_line, 0, 0, rates_total);
   ArrayCopy(signal_line_out, m_signal_line, 0, 0, rates_total);
   ArrayCopy(base_line_out, m_base_line, 0, 0, rates_total);
   ArrayCopy(upper_band_out, m_upper_band, 0, 0, rates_total);
   ArrayCopy(lower_band_out, m_lower_band, 0, 0, rates_total);
  }

//+------------------------------------------------------------------+
//| CTDICalculator: Prepares the source price series.                |
//+------------------------------------------------------------------+
bool CTDICalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   switch(price_type)
     {
      case PRICE_CLOSE:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
      case PRICE_OPEN:
         ArrayCopy(m_price, open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(m_price, high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(m_price, low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (high[i]+low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (high[i]+low[i]+close[i]+close[i])/4.0;
         break;
      default:
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| CTDICalculator: Helper to calculate SMA on an internal buffer    |
//+------------------------------------------------------------------+
double CTDICalculator::CalculateSMA(int position, int period, const double &source_buffer[])
  {
   double sum = 0;
   for(int i = 0; i < period; i++)
      sum += source_buffer[position - i];
   return (period > 0) ? sum / period : 0;
  }

//+==================================================================+
//|                                                                  |
//|             CLASS 2: CTDICalculator_HA (Heikin Ashi)             |
//|                                                                  |
//+==================================================================+
class CTDICalculator_HA : public CTDICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;

protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
  };

//+------------------------------------------------------------------+
//| CTDICalculator_HA: Prepares the source price series.             |
//+------------------------------------------------------------------+
bool CTDICalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- The HA version ALWAYS uses the HA Close price for the RSI calculation
   ArrayCopy(m_price, ha_close, 0, 0, rates_total);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
