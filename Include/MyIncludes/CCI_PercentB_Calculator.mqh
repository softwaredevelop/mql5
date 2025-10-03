//+------------------------------------------------------------------+
//|                                       CCI_PercentB_Calculator.mqh|
//|      Calculation engine for Standard and Heikin Ashi CCI %B.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|         CLASS 1: CCCI_PercentBCalculator (Base Class)            |
//|                                                                  |
//+==================================================================+
class CCCI_PercentBCalculator
  {
protected:
   int               m_cci_period, m_ma_period, m_bands_period;
   ENUM_MA_METHOD    m_ma_method;
   double            m_bands_dev;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

public:
                     CCCI_PercentBCalculator(void) {};
   virtual          ~CCCI_PercentBCalculator(void) {};

   bool              Init(int cci_p, int ma_p, ENUM_MA_METHOD ma_m, int bands_p, double bands_dev);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &percent_b_out[]);
  };

//+------------------------------------------------------------------+
//| CCCI_PercentBCalculator: Initialization                          |
//+------------------------------------------------------------------+
bool CCCI_PercentBCalculator::Init(int cci_p, int ma_p, ENUM_MA_METHOD ma_m, int bands_p, double bands_dev)
  {
   m_cci_period   = (cci_p < 1) ? 1 : cci_p;
   m_ma_period    = (ma_p < 1) ? 1 : ma_p;
   m_ma_method    = ma_m;
   m_bands_period = (bands_p < 1) ? 1 : bands_p;
   m_bands_dev    = (bands_dev <= 0) ? 2.0 : bands_dev;
   return true;
  }

//+------------------------------------------------------------------+
//| CCCI_PercentBCalculator: Main Calculation Method                 |
//+------------------------------------------------------------------+
void CCCI_PercentBCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                                        double &percent_b_out[])
  {
   if(rates_total <= m_cci_period + m_bands_period)
      return;
   if(!PreparePriceSeries(rates_total, open, high, low, close, price_type))
      return;

   double cci_buffer[], signal_buffer[], upper_buffer[], lower_buffer[];
   ArrayResize(cci_buffer, rates_total);
   ArrayResize(signal_buffer, rates_total);
   ArrayResize(upper_buffer, rates_total);
   ArrayResize(lower_buffer, rates_total);

   double buffer_sma[], buffer_mad[];
   ArrayResize(buffer_sma, rates_total);
   ArrayResize(buffer_mad, rates_total);
   const double CCI_CONSTANT = 0.015;

   double sma_sum = 0;
   for(int i = 0; i < rates_total; i++)
     {
      sma_sum += m_price[i];
      if(i >= m_cci_period)
         sma_sum -= m_price[i - m_cci_period];
      if(i >= m_cci_period - 1)
         buffer_sma[i] = sma_sum / m_cci_period;
     }

   for(int i = m_cci_period - 1; i < rates_total; i++)
     {
      double deviation_sum = 0;
      for(int j = 0; j < m_cci_period; j++)
         deviation_sum += MathAbs(m_price[i - j] - buffer_sma[i]);
      buffer_mad[i] = deviation_sum / m_cci_period;
     }

   for(int i = m_cci_period - 1; i < rates_total; i++)
     {
      if(buffer_mad[i] > 0)
         cci_buffer[i] = (m_price[i] - buffer_sma[i]) / (CCI_CONSTANT * buffer_mad[i]);
     }

   int ma_start_pos = m_cci_period + m_ma_period - 2;
   for(int i = ma_start_pos; i < rates_total; i++)
     {
      switch(m_ma_method)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == ma_start_pos)
              {
               double sum=0;
               for(int j=0; j<m_ma_period; j++)
                  sum+=cci_buffer[i-j];
               signal_buffer[i]=sum/m_ma_period;
              }
            else
              {
               if(m_ma_method==MODE_EMA)
                 {
                  double pr=2.0/(m_ma_period+1.0);
                  signal_buffer[i]=cci_buffer[i]*pr+signal_buffer[i-1]*(1.0-pr);
                 }
               else
                  signal_buffer[i]=(signal_buffer[i-1]*(m_ma_period-1)+cci_buffer[i])/m_ma_period;
              }
            break;
         case MODE_LWMA:
           {double sum=0,w_sum=0; for(int j=0; j<m_ma_period; j++) {int w=m_ma_period-j; sum+=cci_buffer[i-j]*w; w_sum+=w;} if(w_sum>0) signal_buffer[i]=sum/w_sum;}
         break;
         default:
           {double sum=0; for(int j=0; j<m_ma_period; j++) sum+=cci_buffer[i-j]; signal_buffer[i]=sum/m_ma_period;}
         break;
        }
     }

   int bands_start_pos = m_cci_period + m_bands_period - 2;
   for(int i = bands_start_pos; i < rates_total; i++)
     {
      if(signal_buffer[i] == EMPTY_VALUE)
         continue;
      double std_dev=0, sum_sq=0;
      for(int j=0; j<m_bands_period; j++)
         sum_sq+=MathPow(cci_buffer[i-j]-signal_buffer[i],2);
      std_dev=MathSqrt(sum_sq/m_bands_period);
      upper_buffer[i]=signal_buffer[i]+m_bands_dev*std_dev;
      lower_buffer[i]=signal_buffer[i]-m_bands_dev*std_dev;
     }

   for(int i = bands_start_pos; i < rates_total; i++)
     {
      double range = upper_buffer[i] - lower_buffer[i];
      if(range > 0)
         percent_b_out[i] = (cci_buffer[i] - lower_buffer[i]) / range * 100.0;
     }
  }

//+------------------------------------------------------------------+
//| CCCI_PercentBCalculator: Prepares the standard source price.     |
//+------------------------------------------------------------------+
bool CCCI_PercentBCalculator::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   ArrayResize(m_price, rates_total);
   switch(price_type)
     {
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
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
     }
   return true;
  }

//+==================================================================+
//|                                                                  |
//|       CLASS 2: CCCI_PercentBCalculator_HA (Heikin Ashi)          |
//|                                                                  |
//+==================================================================+
class CCCI_PercentBCalculator_HA : public CCCI_PercentBCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| CCCI_PercentBCalculator_HA: Prepares the HA source price.        |
//+------------------------------------------------------------------+
bool CCCI_PercentBCalculator_HA::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
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
            m_price[i] = (ha_high[i]+low[i]+2*ha_close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
