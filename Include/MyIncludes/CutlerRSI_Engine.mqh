//+------------------------------------------------------------------+
//|                                             CutlerRSI_Engine.mqh |
//|    Core calculation engine for all Cutler's RSI-based indicators.|
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CCutlerRSI_Engine (Base Class)                |
//|                                                                  |
//+==================================================================+
class CCutlerRSI_Engine
  {
protected:
   int               m_rsi_period;
   int               m_ma_period;
   ENUM_MA_METHOD    m_ma_method;

   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

public:
                     CCutlerRSI_Engine(void) {};
   virtual          ~CCutlerRSI_Engine(void) {};

   bool              Init(int rsi_p, int ma_p, ENUM_MA_METHOD ma_m);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &rsi_buffer[], double &signal_buffer[]);

   int               GetPeriodRSI(void) const { return m_rsi_period; }
   int               GetPeriodMA(void) const { return m_ma_period; }
  };

//+------------------------------------------------------------------+
//| CCutlerRSI_Engine: Initialization                                |
//+------------------------------------------------------------------+
bool CCutlerRSI_Engine::Init(int rsi_p, int ma_p, ENUM_MA_METHOD ma_m)
  {
   m_rsi_period = (rsi_p < 1) ? 1 : rsi_p;
   m_ma_period  = (ma_p < 1) ? 1 : ma_p;
   m_ma_method  = ma_m;
   return true;
  }

//+------------------------------------------------------------------+
//| CCutlerRSI_Engine: Main Calculation Method (Shared Logic)        |
//+------------------------------------------------------------------+
void CCutlerRSI_Engine::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &rsi_buffer[], double &signal_buffer[])
  {
   if(rates_total <= m_rsi_period)
      return;
   if(!PreparePriceSeries(rates_total, open, high, low, close, price_type))
      return;

   double sum_pos = 0, sum_neg = 0;
   for(int i = 1; i < rates_total; i++)
     {
      double diff = m_price[i] - m_price[i-1];
      sum_pos += (diff > 0) ? diff : 0;
      sum_neg += (diff < 0) ? -diff : 0;
      if(i > m_rsi_period)
        {
         double old_diff = m_price[i - m_rsi_period] - m_price[i - m_rsi_period - 1];
         sum_pos -= (old_diff > 0) ? old_diff : 0;
         sum_neg -= (old_diff < 0) ? -old_diff : 0;
        }
      if(i >= m_rsi_period)
        {
         if(sum_pos + sum_neg > 0)
           {
            double rs = sum_pos / sum_neg;
            rsi_buffer[i] = 100.0 - (100.0 / (1.0 + rs));
           }
         else
           {
            rsi_buffer[i] = 100.0;
           }
        }
     }

   int ma_start_pos = m_rsi_period + m_ma_period - 1;
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
                  sum+=rsi_buffer[i-j];
               signal_buffer[i] = sum/m_ma_period;
              }
            else
              {
               if(m_ma_method == MODE_EMA)
                 {
                  double pr=2.0/(m_ma_period+1.0);
                  signal_buffer[i] = rsi_buffer[i]*pr + signal_buffer[i-1]*(1.0-pr);
                 }
               else
                  signal_buffer[i] = (signal_buffer[i-1]*(m_ma_period-1)+rsi_buffer[i])/m_ma_period;
              }
            break;
         case MODE_LWMA:
           {double lwma_sum=0, weight_sum=0; for(int j=0; j<m_ma_period; j++) {int weight=m_ma_period-j; lwma_sum+=rsi_buffer[i-j]*weight; weight_sum+=weight;} if(weight_sum>0) signal_buffer[i]=lwma_sum/weight_sum;}
         break;
         default:
           {double sum=0; for(int j=0; j<m_ma_period; j++) sum+=rsi_buffer[i-j]; signal_buffer[i] = sum/m_ma_period;}
         break;
        }
     }
  }

//+------------------------------------------------------------------+
//| CCutlerRSI_Engine: Prepares the standard source price series.    |
//+------------------------------------------------------------------+
bool CCutlerRSI_Engine::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
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
//|         CLASS 2: CCutlerRSI_Engine_HA (Heikin Ashi)              |
//|                                                                  |
//+==================================================================+
class CCutlerRSI_Engine_HA : public CCutlerRSI_Engine
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| CCutlerRSI_Engine_HA: Prepares the Heikin Ashi source price.     |
//+------------------------------------------------------------------+
bool CCutlerRSI_Engine_HA::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
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
