//+------------------------------------------------------------------+
//|                               Stochastic_Adaptive_Calculator.mqh |
//|      Engine for Frank Key's Variable-Length Stochastic.          |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh> // For ENUM_MA_TYPE
#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
class CStochasticAdaptiveCalculator
  {
protected:
   int               m_er_period, m_min_period, m_max_period, m_slowing_period, m_d_period;
   ENUM_MA_TYPE      m_d_ma_type;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
   void              CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_TYPE method, int start_pos);

public:
                     CStochasticAdaptiveCalculator(void) {};
   virtual          ~CStochasticAdaptiveCalculator(void) {};

   bool              Init(int er_p, int min_p, int max_p, int slow_p, int d_p, ENUM_MA_TYPE d_ma);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CStochasticAdaptiveCalculator_HA : public CStochasticAdaptiveCalculator
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
bool CStochasticAdaptiveCalculator::Init(int er_p, int min_p, int max_p, int slow_p, int d_p, ENUM_MA_TYPE d_ma)
  {
   m_er_period = (er_p < 1) ? 1 : er_p;
   m_min_period = (min_p < 1) ? 1 : min_p;
   m_max_period = (max_p <= m_min_period) ? m_min_period + 1 : max_p;
   m_slowing_period = (slow_p < 1) ? 1 : slow_p;
   m_d_period = (d_p < 1) ? 1 : d_p;
   m_d_ma_type = d_ma;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStochasticAdaptiveCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &k_buffer[], double &d_buffer[])
  {
   if(rates_total <= m_er_period + m_max_period)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   double er_buffer[], nsp_buffer[], raw_k[];
   ArrayResize(er_buffer, rates_total);
   ArrayResize(nsp_buffer, rates_total);
   ArrayResize(raw_k, rates_total);

   for(int i = m_er_period; i < rates_total; i++)
     {
      double direction = MathAbs(m_price[i] - m_price[i - m_er_period]);
      double volatility = 0;
      for(int j = 0; j < m_er_period; j++)
         volatility += MathAbs(m_price[i - j] - m_price[i - j - 1]);
      er_buffer[i] = (volatility > 0.000001) ? direction / volatility : 0;
     }

   for(int i = m_er_period; i < rates_total; i++)
     {
      nsp_buffer[i] = (int)(er_buffer[i] * (m_max_period - m_min_period) + m_min_period);
      if(nsp_buffer[i] < 1)
         nsp_buffer[i] = 1;
     }

   for(int i = m_er_period + m_max_period - 1; i < rates_total; i++)
     {
      int current_nsp = (int)nsp_buffer[i];
      double highest = m_price[i], lowest = m_price[i];
      for(int j = 1; j < current_nsp; j++)
        {
         if(i-j < 0)
            break;
         highest = MathMax(highest, m_price[i-j]);
         lowest = MathMin(lowest, m_price[i-j]);
        }
      double range = highest - lowest;
      if(range > 0.000001)
         raw_k[i] = (m_price[i] - lowest) / range * 100.0;
      else
         raw_k[i] = (i > 0) ? raw_k[i-1] : 50.0;
     }

   int k_slow_start = m_er_period + m_max_period + m_slowing_period - 2;
   CalculateMA(raw_k, k_buffer, m_slowing_period, SMA, k_slow_start);
   int d_start = k_slow_start + m_d_period - 1;
   CalculateMA(k_buffer, d_buffer, m_d_period, m_d_ma_type, d_start);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStochasticAdaptiveCalculator::CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_TYPE method, int start_pos)
  {
   for(int i = start_pos; i < ArraySize(source_array); i++)
     {
      switch(method)
        {
         case EMA:
         case SMMA:
            if(i == start_pos)
              {
               double sum=0;
               int count=0;
               for(int j=0; j<period; j++)
                 {
                  if(source_array[i-j] != EMPTY_VALUE)
                    {
                     sum+=source_array[i-j];
                     count++;
                    }
                 }
               if(count > 0)
                  dest_array[i]=sum/count;
              }
            else
              {
               if(method==EMA)
                 {
                  double pr=2.0/(period+1.0);
                  dest_array[i]=source_array[i]*pr+dest_array[i-1]*(1.0-pr);
                 }
               else
                  dest_array[i]=(dest_array[i-1]*(period-1)+source_array[i])/period;
              }
            break;
         case LWMA:
           {
            double sum=0, w_sum=0;
            for(int j=0; j<period; j++)
              {
               if(source_array[i-j] == EMPTY_VALUE)
                  continue;
               int w=period-j;
               sum+=source_array[i-j]*w;
               w_sum+=w;
              }
            if(w_sum>0)
               dest_array[i]=sum/w_sum;
           }
         break;
         default: // SMA
           {
            double sum=0;
            int count=0;
            for(int j=0; j<period; j++)
              {
               if(source_array[i-j] != EMPTY_VALUE)
                 {
                  sum+=source_array[i-j];
                  count++;
                 }
              }
            if(count > 0)
               dest_array[i]=sum/count;
           }
         break;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CStochasticAdaptiveCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
bool CStochasticAdaptiveCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
