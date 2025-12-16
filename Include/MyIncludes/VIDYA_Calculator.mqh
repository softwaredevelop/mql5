//+------------------------------------------------------------------+
//|                                             VIDYA_Calculator.mqh |
//|      VERSION 3.11: Fixed override signature mismatch.            |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CVIDYACalculator (Base Class)               |
//+==================================================================+
class CVIDYACalculator
  {
protected:
   int               m_cmo_period, m_ema_period;

   //--- Persistent Buffer for Incremental Calculation
   double            m_price[];

   double            CalculateCMO(int position, int period, const double &price_array[]);

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CVIDYACalculator(void) {};
   virtual          ~CVIDYACalculator(void) {};

   bool              Init(int cmo_p, int ema_p);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &vidya_buffer[]);

   //--- Overloaded Method 2: For multi-color VIDYA
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &vidya_up_buffer[], double &vidya_down_buffer[]);

   int               GetPeriod(void) const { return m_cmo_period + m_ema_period; }
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CVIDYACalculator::Init(int cmo_p, int ema_p)
  {
   m_cmo_period = (cmo_p < 1) ? 1 : cmo_p;
   m_ema_period = (ema_p < 1) ? 1 : ema_p;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Single Color - Optimized)                      |
//+------------------------------------------------------------------+
void CVIDYACalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                 double &vidya_buffer[])
  {
   int start_pos = m_cmo_period + m_ema_period;
   if(rates_total <= start_pos)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   double alpha = 2.0 / (m_ema_period + 1.0);
   int loop_start = MathMax(start_pos, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      if(i == start_pos)
        {
         double sum=0;
         for(int j=0; j<m_ema_period; j++)
            sum+=m_price[i-j];
         vidya_buffer[i]=sum/m_ema_period;
         continue;
        }

      double cmo_abs = MathAbs(CalculateCMO(i, m_cmo_period, m_price));
      vidya_buffer[i] = m_price[i] * alpha * cmo_abs + vidya_buffer[i-1] * (1 - alpha * cmo_abs);
     }
  }

//+------------------------------------------------------------------+
//| Main Calculation (Multi Color - Optimized)                       |
//+------------------------------------------------------------------+
void CVIDYACalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                 double &vidya_up_buffer[], double &vidya_down_buffer[])
  {
   int start_pos = m_cmo_period + m_ema_period;
   if(rates_total <= start_pos)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   double alpha = 2.0 / (m_ema_period + 1.0);
   int loop_start = MathMax(start_pos, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      vidya_up_buffer[i] = EMPTY_VALUE;
      vidya_down_buffer[i] = EMPTY_VALUE;

      double prev_vidya = 0;
      if(i > start_pos)
        {
         if(vidya_up_buffer[i-1] != EMPTY_VALUE)
            prev_vidya = vidya_up_buffer[i-1];
         else
            if(vidya_down_buffer[i-1] != EMPTY_VALUE)
               prev_vidya = vidya_down_buffer[i-1];
        }

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
      else
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
        }
     }
  }

//+------------------------------------------------------------------+
//| Helper: Calculate CMO                                            |
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
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CVIDYACalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = high[i];
            break;
         case PRICE_LOW:
            m_price[i] = low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (high[i]+low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CVIDYACalculator_HA (Heikin Ashi)           |
//+==================================================================+
class CVIDYACalculator_HA : public CVIDYACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CVIDYACalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

//--- Copy to m_price (Optimized loop)
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = m_ha_close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = m_ha_open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = m_ha_high[i];
            break;
         case PRICE_LOW:
            m_price[i] = m_ha_low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (m_ha_high[i]+m_ha_low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+m_ha_close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+2*m_ha_close[i])/4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
