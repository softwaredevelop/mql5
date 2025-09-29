//+------------------------------------------------------------------+
//|                                     CCI_Oscillator_Calculator.mqh|
//| Calculation engine for Standard and Heikin Ashi CCI Oscillator.  |
//|             (Self-contained version with duplicated logic)       |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|         CLASS 1: CCCI_OscillatorCalculator (Base Class)          |
//|                                                                  |
//+==================================================================+
class CCCI_OscillatorCalculator
  {
protected:
   int               m_cci_period;
   int               m_ma_period;
   ENUM_MA_METHOD    m_ma_method;

   //--- Internal buffer for the selected source price
   double            m_price[];

   //--- Virtual method for preparing the price series.
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

public:
                     CCCI_OscillatorCalculator(void) {};
   virtual          ~CCCI_OscillatorCalculator(void) {};

   //--- Public methods
   bool              Init(int cci_p, int ma_p, ENUM_MA_METHOD ma_m);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &osc_buffer[]);
  };

//+------------------------------------------------------------------+
//| CCCI_OscillatorCalculator: Initialization                        |
//+------------------------------------------------------------------+
bool CCCI_OscillatorCalculator::Init(int cci_p, int ma_p, ENUM_MA_METHOD ma_m)
  {
   m_cci_period = (cci_p < 1) ? 1 : cci_p;
   m_ma_period  = (ma_p < 1) ? 1 : ma_p;
   m_ma_method  = ma_m;
   return true;
  }

//+------------------------------------------------------------------+
//| CCCI_OscillatorCalculator: Main Calculation Method               |
//+------------------------------------------------------------------+
void CCCI_OscillatorCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &osc_buffer[])
  {
   int start_pos = m_cci_period + m_ma_period - 2;
   if(rates_total <= start_pos)
      return;

//--- STEP 1: Prepare the source price array (delegated to virtual method)
   if(!PreparePriceSeries(rates_total, open, high, low, close, price_type))
      return;

//--- Internal calculation buffers
   double buffer_cci[], buffer_signal[];
   ArrayResize(buffer_cci, rates_total);
   ArrayResize(buffer_signal, rates_total);

   double buffer_sma[], buffer_mad[];
   ArrayResize(buffer_sma, rates_total);
   ArrayResize(buffer_mad, rates_total);
   const double CCI_CONSTANT = 0.015;

//--- STEP 2: Calculate the Simple Moving Average of the price
   double sma_sum = 0;
   for(int i = 0; i < rates_total; i++)
     {
      sma_sum += m_price[i];
      if(i >= m_cci_period)
         sma_sum -= m_price[i - m_cci_period];
      if(i >= m_cci_period - 1)
         buffer_sma[i] = sma_sum / m_cci_period;
     }

//--- STEP 3: Calculate the Mean Absolute Deviation (MAD)
   for(int i = m_cci_period - 1; i < rates_total; i++)
     {
      double deviation_sum = 0;
      for(int j = 0; j < m_cci_period; j++)
        {
         deviation_sum += MathAbs(m_price[i - j] - buffer_sma[i]);
        }
      buffer_mad[i] = deviation_sum / m_cci_period;
     }

//--- STEP 4: Calculate the final CCI value
   for(int i = m_cci_period - 1; i < rates_total; i++)
     {
      if(buffer_mad[i] > 0)
         buffer_cci[i] = (m_price[i] - buffer_sma[i]) / (CCI_CONSTANT * buffer_mad[i]);
     }

//--- STEP 5: Calculate the Signal Line (MA of CCI)
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
                  sum+=buffer_cci[i-j];
               buffer_signal[i] = sum/m_ma_period;
              }
            else
              {
               if(m_ma_method == MODE_EMA)
                 {
                  double pr=2.0/(m_ma_period+1.0);
                  buffer_signal[i] = buffer_cci[i]*pr + buffer_signal[i-1]*(1.0-pr);
                 }
               else
                  buffer_signal[i] = (buffer_signal[i-1]*(m_ma_period-1)+buffer_cci[i])/m_ma_period;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<m_ma_period; j++)
              {
               int weight=m_ma_period-j;
               lwma_sum+=buffer_cci[i-j]*weight;
               weight_sum+=weight;
              }
            if(weight_sum>0)
               buffer_signal[i]=lwma_sum/weight_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<m_ma_period; j++)
               sum+=buffer_cci[i-j];
            buffer_signal[i] = sum/m_ma_period;
           }
         break;
        }
     }

//--- STEP 6: Calculate the final Oscillator value
   for(int i = ma_start_pos; i < rates_total; i++)
     {
      osc_buffer[i] = buffer_cci[i] - buffer_signal[i];
     }
  }

//+------------------------------------------------------------------+
//| CCCI_OscillatorCalculator: Prepares the standard source price.   |
//+------------------------------------------------------------------+
bool CCCI_OscillatorCalculator::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
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
//|       CLASS 2: CCCI_OscillatorCalculator_HA (Heikin Ashi)        |
//|                                                                  |
//+==================================================================+
class CCCI_OscillatorCalculator_HA : public CCCI_OscillatorCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| CCCI_OscillatorCalculator_HA: Prepares the HA source price.      |
//+------------------------------------------------------------------+
bool CCCI_OscillatorCalculator_HA::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
//--- First, calculate the HA candles
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- Now, populate the m_price array from the calculated HA candles
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
            m_price[i] = (ha_high[i]+ha_low[i]+2*ha_close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
