//+------------------------------------------------------------------+
//|                                         MovingAverage_Engine.mqh |
//|      VERSION 1.30: Added DEMA and TEMA for lag reduction.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- UPDATED: Enum to select the MA type for calculation ---
enum ENUM_MA_TYPE
  {
   SMA,
   EMA,
   SMMA,
   LWMA,
   TMA,
   DEMA,
   TEMA
  };

//+==================================================================+
class CMovingAverageCalculator
  {
protected:
   int               m_period;
   ENUM_MA_TYPE      m_ma_type;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
   void              CalculateEMA(int rates_total, int period, const double &source[], double &dest[]);

public:
                     CMovingAverageCalculator(void) {};
   virtual          ~CMovingAverageCalculator(void) {};

   bool              Init(int period, ENUM_MA_TYPE ma_type);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &ma_buffer[]);
   int               GetPeriod(void) const { return m_period; }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CMovingAverageCalculator_HA : public CMovingAverageCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMovingAverageCalculator::Init(int period, ENUM_MA_TYPE ma_type)
  {
   m_period = (period < 1) ? 1 : period;
   m_ma_type = ma_type;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &ma_buffer[])
  {
   if(rates_total < m_period)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   int start_pos = m_period - 1;
   for(int i = 0; i < rates_total; i++) // Clear all values initially
      ma_buffer[i] = EMPTY_VALUE;

   switch(m_ma_type)
     {
      case EMA:
         CalculateEMA(rates_total, m_period, m_price, ma_buffer);
         break;
      case SMMA:
         for(int i = start_pos; i < rates_total; i++)
           {
            if(i == start_pos)
              {
               double sum=0;
               for(int j=0; j<m_period; j++)
                  sum+=m_price[i-j];
               ma_buffer[i]=sum/m_period;
              }
            else
               ma_buffer[i]=(ma_buffer[i-1]*(m_period-1)+m_price[i])/m_period;
           }
         break;
      case LWMA:
         for(int i = start_pos; i < rates_total; i++)
           {
            double sum=0, w_sum=0;
            for(int j=0; j<m_period; j++)
              {
               int w=m_period-j;
               sum+=m_price[i-j]*w;
               w_sum+=w;
              }
            if(w_sum>0)
               ma_buffer[i]=sum/w_sum;
           }
         break;
      case TMA:
        {
         double sma1_buffer[];
         ArrayResize(sma1_buffer, rates_total);
         int period1 = (int)ceil((m_period + 1.0) / 2.0);

         for(int i = period1 - 1; i < rates_total; i++)
           {
            double sum = 0;
            for(int j = 0; j < period1; j++)
               sum += m_price[i-j];
            sma1_buffer[i] = sum / period1;
           }

         int period2 = m_period - period1 + 1;
         for(int i = period1 + period2 - 2; i < rates_total; i++)
           {
            double sum = 0;
            for(int j = 0; j < period2; j++)
               sum += sma1_buffer[i-j];
            ma_buffer[i] = sum / period2;
           }
        }
      break;
      case DEMA:
        {
         double ema1[], ema2[];
         ArrayResize(ema1, rates_total);
         ArrayResize(ema2, rates_total);
         CalculateEMA(rates_total, m_period, m_price, ema1);
         CalculateEMA(rates_total, m_period, ema1, ema2);
         for(int i = (m_period - 1) * 2; i < rates_total; i++)
            ma_buffer[i] = 2 * ema1[i] - ema2[i];
         break;
        }
      case TEMA:
        {
         double ema1[], ema2[], ema3[];
         ArrayResize(ema1, rates_total);
         ArrayResize(ema2, rates_total);
         ArrayResize(ema3, rates_total);
         CalculateEMA(rates_total, m_period, m_price, ema1);
         CalculateEMA(rates_total, m_period, ema1, ema2);
         CalculateEMA(rates_total, m_period, ema2, ema3);
         for(int i = (m_period - 1) * 3; i < rates_total; i++)
            ma_buffer[i] = 3 * ema1[i] - 3 * ema2[i] + ema3[i];
         break;
        }
      default: // SMA
         for(int i = start_pos; i < rates_total; i++)
           {
            double sum=0;
            for(int j=0; j<m_period; j++)
               sum+=m_price[i-j];
            ma_buffer[i]=sum/m_period;
           }
         break;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::CalculateEMA(int rates_total, int period, const double &source[], double &dest[])
  {
   if(rates_total < period)
      return;
   int start_pos = period - 1;
   double pr = 2.0 / (double)(period + 1.0);

   for(int i=0; i<start_pos; i++)
      dest[i] = EMPTY_VALUE;

   double sum=0;
   for(int j=0; j<period; j++)
      if(source[start_pos-j] != EMPTY_VALUE)
         sum += source[start_pos-j];
   dest[start_pos] = sum / period;

   for(int i = start_pos + 1; i < rates_total; i++)
     {
      if(source[i] != EMPTY_VALUE)
         dest[i] = source[i] * pr + dest[i-1] * (1.0 - pr);
      else
         dest[i] = dest[i-1];
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMovingAverageCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
      if(ArrayResize(m_price, rates_total) != rates_total)
         return false;

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
//|                                                                  |
//+------------------------------------------------------------------+
bool CMovingAverageCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   if(ArraySize(m_price) != rates_total)
      if(ArrayResize(m_price, rates_total) != rates_total)
         return false;

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
