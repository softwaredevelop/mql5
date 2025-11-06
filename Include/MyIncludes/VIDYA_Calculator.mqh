//+------------------------------------------------------------------+
//|                                             VIDYA_Calculator.mqh |
//|         Universal engine for VIDYA (single and multi-color).     |
//|         VERSION 3.00: Implemented method overloading.            |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
class CVIDYACalculator
  {
protected:
   int               m_cmo_period, m_ema_period;
   double            m_price[];

   double            CalculateCMO(int position, int period, const double &price_array[]);
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CVIDYACalculator(void) {};
   virtual          ~CVIDYACalculator(void) {};

   bool              Init(int cmo_p, int ema_p);

   //--- Overloaded Method 1: For single-color VIDYA
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &vidya_buffer[]);

   //--- Overloaded Method 2: For multi-color VIDYA
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &vidya_up_buffer[], double &vidya_down_buffer[]);
  };

//+------------------------------------------------------------------+
bool CVIDYACalculator::Init(int cmo_p, int ema_p)
  {
   m_cmo_period = (cmo_p < 1) ? 1 : cmo_p;
   m_ema_period = (ema_p < 1) ? 1 : ema_p;
   return true;
  }

//+------------------------------------------------------------------+
//| Implementation for SINGLE-COLOR VIDYA                            |
//+------------------------------------------------------------------+
void CVIDYACalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                 double &vidya_buffer[])
  {
   int start_pos = m_cmo_period + m_ema_period;
   if(rates_total <= start_pos)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   double alpha = 2.0 / (m_ema_period + 1.0);

   for(int i = 1; i < rates_total; i++)
     {
      if(i == start_pos)
        {
         double sum=0;
         for(int j=0; j<m_ema_period; j++)
            sum+=m_price[i-j];
         vidya_buffer[i]=sum/m_ema_period;
         continue;
        }
      if(i > start_pos)
        {
         double cmo_abs = MathAbs(CalculateCMO(i, m_cmo_period, m_price));
         vidya_buffer[i] = m_price[i] * alpha * cmo_abs + vidya_buffer[i-1] * (1 - alpha * cmo_abs);
        }
     }
  }

//+------------------------------------------------------------------+
//| Implementation for MULTI-COLOR VIDYA                             |
//+------------------------------------------------------------------+
void CVIDYACalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                 double &vidya_up_buffer[], double &vidya_down_buffer[])
  {
   int start_pos = m_cmo_period + m_ema_period;
   if(rates_total <= start_pos)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   double alpha = 2.0 / (m_ema_period + 1.0);
   double prev_vidya = 0.0;

   for(int i = 1; i < rates_total; i++)
     {
      vidya_up_buffer[i] = EMPTY_VALUE;
      vidya_down_buffer[i] = EMPTY_VALUE;

      if(i == start_pos)
        {
         double sum=0;
         for(int j=0; j<m_ema_period; j++)
            sum+=m_price[i-j];
         prev_vidya = sum/m_ema_period;

         double cmo_raw = CalculateCMO(i, m_cmo_period, m_price);
         if(cmo_raw > 0)
            vidya_up_buffer[i] = prev_vidya;
         else
            vidya_down_buffer[i] = prev_vidya;
        }
      if(i > start_pos)
        {
         double cmo_raw = CalculateCMO(i, m_cmo_period, m_price);
         double cmo_abs = MathAbs(cmo_raw);
         double current_vidya = m_price[i] * alpha * cmo_abs + prev_vidya * (1 - alpha * cmo_abs);

         if(cmo_raw > 0)
            vidya_up_buffer[i] = current_vidya;
         else
            vidya_down_buffer[i] = current_vidya;

         double cmo_raw_prev = CalculateCMO(i-1, m_cmo_period, m_price);
         if((cmo_raw > 0) != (cmo_raw_prev > 0))
           {
            vidya_up_buffer[i-1] = prev_vidya;
            vidya_down_buffer[i-1] = prev_vidya;
           }

         prev_vidya = current_vidya;
        }
     }
  }

//+------------------------------------------------------------------+
//| CVIDYACalculator: Helper to calculate CMO                        |
//+------------------------------------------------------------------+
double CVIDYACalculator::CalculateCMO(int position, int period, const double &price_array[])
  {
   if(position < period)
      return 0.0;
   double sum_up = 0.0, sum_down = 0.0;
   for(int i = 0; i < period; i++)
     {
      double diff = price_array[position - i] - price_array[position - i - 1];
      if(diff > 0.0)
         sum_up += diff;
      else
         sum_down += (-diff);
     }
   if(sum_up + sum_down == 0.0)
      return 0.0;
   return (sum_up - sum_down) / (sum_up + sum_down);
  }
//+------------------------------------------------------------------+
//| CVIDYACalculator: Prepares the standard source price.            |
//+------------------------------------------------------------------+
bool CVIDYACalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
class CVIDYACalculator_HA : public CVIDYACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };
//+------------------------------------------------------------------+
bool CVIDYACalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
