//+------------------------------------------------------------------+
//|                                                 CCI_Engine.mqh   |
//|      Core calculation engine for all CCI-based indicators.       |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CCCI_Engine (Base Class)                    |
//|                                                                  |
//+==================================================================+
class CCCI_Engine
  {
protected:
   int               m_cci_period;
   int               m_ma_period;
   ENUM_MA_METHOD    m_ma_method;

   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

public:
                     CCCI_Engine(void) {};
   virtual          ~CCCI_Engine(void) {};

   bool              Init(int cci_p, int ma_p, ENUM_MA_METHOD ma_m);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &cci_buffer[], double &signal_buffer[]);

   int               GetPeriodCCI(void) const { return m_cci_period; }
   int               GetPeriodMA(void) const { return m_ma_period; }
  };

//+------------------------------------------------------------------+
//| CCCI_Engine: Initialization                                      |
//+------------------------------------------------------------------+
bool CCCI_Engine::Init(int cci_p, int ma_p, ENUM_MA_METHOD ma_m)
  {
   m_cci_period = (cci_p < 1) ? 1 : cci_p;
   m_ma_period  = (ma_p < 1) ? 1 : ma_p;
   m_ma_method  = ma_m;
   return true;
  }

//+------------------------------------------------------------------+
//| CCCI_Engine: Main Calculation Method (Shared Logic)              |
//+------------------------------------------------------------------+
void CCCI_Engine::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &cci_buffer[], double &signal_buffer[])
  {
   int start_pos = m_cci_period + m_ma_period - 2;
   if(rates_total <= start_pos)
      return;

   if(!PreparePriceSeries(rates_total, open, high, low, close, price_type))
      return;

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
        {
         deviation_sum += MathAbs(m_price[i - j] - buffer_sma[i]);
        }
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
               signal_buffer[i] = sum/m_ma_period;
              }
            else
              {
               if(m_ma_method == MODE_EMA)
                 {
                  double pr=2.0/(m_ma_period+1.0);
                  signal_buffer[i] = cci_buffer[i]*pr + signal_buffer[i-1]*(1.0-pr);
                 }
               else
                  signal_buffer[i] = (signal_buffer[i-1]*(m_ma_period-1)+cci_buffer[i])/m_ma_period;
              }
            break;
         case MODE_LWMA:
           {double lwma_sum=0, weight_sum=0; for(int j=0; j<m_ma_period; j++) {int weight=m_ma_period-j; lwma_sum+=cci_buffer[i-j]*weight; weight_sum+=weight;} if(weight_sum>0) signal_buffer[i]=lwma_sum/weight_sum;}
         break;
         default:
           {double sum=0; for(int j=0; j<m_ma_period; j++) sum+=cci_buffer[i-j]; signal_buffer[i] = sum/m_ma_period;}
         break;
        }
     }
  }

//+------------------------------------------------------------------+
//| CCCI_Engine: Prepares the standard source price series.          |
//+------------------------------------------------------------------+
bool CCCI_Engine::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
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
//|           CLASS 2: CCCI_Engine_HA (Heikin Ashi)                  |
//|                                                                  |
//+==================================================================+
class CCCI_Engine_HA : public CCCI_Engine
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| CCCI_Engine_HA: Prepares the Heikin Ashi source price.           |
//+------------------------------------------------------------------+
bool CCCI_Engine_HA::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
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
