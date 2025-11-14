//+------------------------------------------------------------------+
//|                                         VIDYA_Stdev_Calculator.mqh |
//|      VERSION 1.20: Corrected Stdev to manual calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
class CVIDYAStdevCalculator
  {
protected:
   int               m_vidya_period, m_stdev_short, m_stdev_long;
   double            m_price[];
   double            m_prev_vidya;

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
   //--- Helper function for manual Standard Deviation calculation ---
   double            CalculateStdDev(const double &array[], int period, int position);

public:
                     CVIDYAStdevCalculator(void) : m_prev_vidya(0) {};
   virtual          ~CVIDYAStdevCalculator(void) {};

   bool              Init(int vidya_p, int stdev_s, int stdev_l);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &vidya_buffer[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CVIDYAStdevCalculator_HA : public CVIDYAStdevCalculator
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
bool CVIDYAStdevCalculator::Init(int vidya_p, int stdev_s, int stdev_l)
  {
   m_vidya_period = (vidya_p < 1) ? 1 : vidya_p;
   m_stdev_short = (stdev_s < 1) ? 1 : stdev_s;
   m_stdev_long = (stdev_l <= m_stdev_short) ? m_stdev_short + 1 : stdev_l;
   m_prev_vidya = 0;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CVIDYAStdevCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &vidya_buffer[])
  {
   if(rates_total <= m_stdev_long)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   double stdev_short_buff[], stdev_long_buff[];
   ArrayResize(stdev_short_buff, rates_total);
   ArrayResize(stdev_long_buff, rates_total);

//--- STEP 1: Calculate Standard Deviations manually ---
   for(int i = m_stdev_long - 1; i < rates_total; i++)
     {
      if(i >= m_stdev_short - 1)
         stdev_short_buff[i] = CalculateStdDev(m_price, m_stdev_short, i);

      stdev_long_buff[i] = CalculateStdDev(m_price, m_stdev_long, i);
     }

//--- STEP 2: Calculate VIDYA
   double alpha = 2.0 / (m_vidya_period + 1.0);
   int start_pos = m_stdev_long;

   if(ArraySize(vidya_buffer) == 0 || vidya_buffer[start_pos-1] == 0)
     {
      m_prev_vidya = m_price[start_pos-1];
     }

   for(int i = start_pos; i < rates_total; i++)
     {
      double k = (stdev_long_buff[i] > 0.000001) ? stdev_short_buff[i] / stdev_long_buff[i] : 1.0;

      double alpha_k = alpha * k;
      if(alpha_k > 1.0)
         alpha_k = 1.0;

      vidya_buffer[i] = m_price[i] * alpha_k + m_prev_vidya * (1.0 - alpha_k);

      m_prev_vidya = vidya_buffer[i];
     }
  }

//--- NEW: Helper function for manual Standard Deviation calculation ---
double CVIDYAStdevCalculator::CalculateStdDev(const double &array[], int period, int position)
  {
   if(position < period - 1)
      return 0.0;

// 1. Calculate the average (SMA)
   double sum = 0;
   for(int i = 0; i < period; i++)
      sum += array[position - i];
   double avg = sum / period;

// 2. Calculate the sum of squared differences
   double sum_sq = 0;
   for(int i = 0; i < period; i++)
      sum_sq += pow(array[position - i] - avg, 2);

// 3. Return the standard deviation
   return sqrt(sum_sq / period);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CVIDYAStdevCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
bool CVIDYAStdevCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
