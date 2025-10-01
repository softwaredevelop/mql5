//+------------------------------------------------------------------+
//|                                               TDI_Calculator.mqh |
//|        Calculation engine for Standard and Heikin Ashi TDI.      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CTDICalculator (Base Class)                 |
//|                                                                  |
//+==================================================================+
class CTDICalculator
  {
protected:
   int               m_rsi_period, m_price_period, m_signal_period, m_base_period;
   double            m_std_dev;
   double            m_price[];

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
   m_rsi_period    = (rsi_p < 1) ? 1 : rsi_p;
   m_price_period  = (price_p < 1) ? 1 : price_p;
   m_signal_period = (signal_p < 1) ? 1 : signal_p;
   m_base_period   = (base_p < 1) ? 1 : base_p;
   m_std_dev       = (dev <= 0) ? 1.618 : dev;
   return true;
  }

//+------------------------------------------------------------------+
//| CTDICalculator: Main Calculation Method (Definition-True)        |
//+------------------------------------------------------------------+
void CTDICalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &price_line_out[], double &signal_line_out[], double &base_line_out[],
                               double &upper_band_out[], double &lower_band_out[])
  {
   if(rates_total <= m_rsi_period + m_base_period)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   double rsi_buffer[];
   ArrayResize(rsi_buffer, rates_total);

//--- STEP 1: Calculate RSI (Wilder's smoothing)
   double sum_pos = 0, sum_neg = 0;
   for(int i = 1; i < rates_total; i++)
     {
      double diff = m_price[i] - m_price[i-1];
      sum_pos = (sum_pos * (m_rsi_period - 1) + (diff > 0 ? diff : 0)) / m_rsi_period;
      sum_neg = (sum_neg * (m_rsi_period - 1) + (diff < 0 ? -diff : 0)) / m_rsi_period;
      if(i >= m_rsi_period)
        {
         if(sum_neg > 0)
            rsi_buffer[i] = 100.0 - (100.0 / (1.0 + (sum_pos / sum_neg)));
         else
            rsi_buffer[i] = 100.0;
        }
     }

//--- STEP 2: Calculate Price Line (SMA on RSI)
   for(int i = m_rsi_period + m_price_period - 2; i < rates_total; i++)
     {
      double sum=0;
      for(int j=0; j<m_price_period; j++)
         sum+=rsi_buffer[i-j];
      price_line_out[i]=sum/m_price_period;
     }

//--- STEP 3: Calculate Signal Line (SMA on Price Line)
   for(int i = m_rsi_period + m_price_period + m_signal_period - 3; i < rates_total; i++)
     {
      double sum=0;
      for(int j=0; j<m_signal_period; j++)
         sum+=price_line_out[i-j];
      signal_line_out[i]=sum/m_signal_period;
     }

//--- STEP 4: Calculate Base Line (SMA on Price Line)
   for(int i = m_rsi_period + m_price_period + m_base_period - 3; i < rates_total; i++)
     {
      double sum=0;
      for(int j=0; j<m_base_period; j++)
         sum+=price_line_out[i-j];
      base_line_out[i]=sum/m_base_period;
     }

//--- STEP 5: Calculate Volatility Bands (Bollinger Bands on Base Line, using RSI data for StdDev)
   int bands_start = m_rsi_period + m_base_period - 2; // BBands on RSI, centered on Base Line
   for(int i = bands_start; i < rates_total; i++)
     {
      double std_dev = 0, sum_sq = 0;
      // The standard deviation for TDI bands is calculated on the RSI, not the base line itself.
      double base_line_ma_on_rsi = 0;
      double sum_rsi = 0;
      for(int j=0; j<m_base_period; j++)
         sum_rsi += rsi_buffer[i-j];
      base_line_ma_on_rsi = sum_rsi / m_base_period;

      for(int j = 0; j < m_base_period; j++)
         sum_sq += MathPow(rsi_buffer[i-j] - base_line_ma_on_rsi, 2);
      std_dev = MathSqrt(sum_sq / m_base_period);

      upper_band_out[i] = base_line_out[i] + m_std_dev * std_dev;
      lower_band_out[i] = base_line_out[i] - m_std_dev * std_dev;
     }
  }

//+------------------------------------------------------------------+
//| CTDICalculator: Prepares the standard source price series.       |
//+------------------------------------------------------------------+
bool CTDICalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);
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
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CTDICalculator_HA: Prepares the Heikin Ashi source price.        |
//+------------------------------------------------------------------+
bool CTDICalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_price, rates_total);
   switch(price_type)
     {
      case PRICE_CLOSE:
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
      case PRICE_OPEN:
         ArrayCopy(m_price, ha_open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(m_price, ha_high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(m_price, ha_low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (ha_high[i]+ha_low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (ha_high[i]+ha_low[i]+ha_close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (ha_high[i]+ha_low[i]+ha_close[i]+ha_close[i])/4.0;
         break;
      default:
         return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
