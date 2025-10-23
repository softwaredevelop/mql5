//+------------------------------------------------------------------+
//|                                     ZeroLag_EMA_Calculator.mqh   |
//|      Calculation engine for the John Ehlers' Zero-Lag EMA.       |
//|      Supports standard (double EMA) and optimized gain modes.    |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CZeroLagEMACalculator (Base Class)            |
//|                                                                  |
//+==================================================================+
class CZeroLagEMACalculator
  {
protected:
   int               m_period;
   bool              m_optimize_gain;
   double            m_gain_limit;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CZeroLagEMACalculator(void) {};
   virtual          ~CZeroLagEMACalculator(void) {};

   bool              Init(int period, bool optimize_gain, double gain_limit);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &zlema_buffer[]);
  };

//+------------------------------------------------------------------+
bool CZeroLagEMACalculator::Init(int period, bool optimize_gain, double gain_limit)
  {
   m_period = (period < 1) ? 1 : period;
   m_optimize_gain = optimize_gain;
   m_gain_limit = gain_limit;
   return true;
  }

//+------------------------------------------------------------------+
void CZeroLagEMACalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &zlema_buffer[])
  {
   if(rates_total < m_period * 2)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   double alpha = 2.0 / (m_period + 1.0);

   if(!m_optimize_gain)
     {
      // --- Standard (Double EMA) Zero-Lag EMA Calculation ---
      double ema1_buffer[], ema2_buffer[];
      ArrayResize(ema1_buffer, rates_total);
      ArrayResize(ema2_buffer, rates_total);
      double ema1_prev = 0, ema2_prev = 0;

      for(int i = 0; i < rates_total; i++)
        {
         if(i == m_period - 1)
           {
            double sum=0;
            for(int j=0; j<m_period; j++)
               sum+=m_price[i-j];
            ema1_prev = sum/m_period;
           }
         if(i >= m_period)
           {
            double ema1 = m_price[i] * alpha + (1.0 - alpha) * ema1_prev;
            ema1_buffer[i] = ema1;
            if(i == m_period * 2 - 2)
              {
               double sum=0;
               for(int j=0; j<m_period; j++)
                  sum+=ema1_buffer[i-j];
               ema2_prev = sum/m_period;
              }
            if(i >= m_period * 2 - 1)
              {
               double ema2 = ema1_buffer[i] * alpha + (1.0 - alpha) * ema2_prev;
               zlema_buffer[i] = 2.0 * ema1 - ema2;
               ema2_prev = ema2;
              }
            ema1_prev = ema1;
           }
        }
     }
   else
     {
      // --- Ehlers' Optimized Gain (Error Correcting) Calculation ---
      double ema_buffer[];
      ArrayResize(ema_buffer, rates_total);
      double ema_prev = 0;
      double ec_prev = 0;

      for(int i = 0; i < rates_total; i++)
        {
         // Calculate standard EMA first
         if(i > 0)
            ema_buffer[i] = m_price[i] * alpha + (1.0 - alpha) * ema_prev;
         else
            ema_buffer[i] = m_price[i];
         ema_prev = ema_buffer[i];

         if(i < 1)
           {
            zlema_buffer[i] = m_price[i];
            ec_prev = m_price[i];
            continue;
           }

         // Find the BestGain for the current bar
         double least_error = 1e10;
         double best_gain = 0;
         int gain_steps = (int)(m_gain_limit * 10);

         for(int j = -gain_steps; j <= gain_steps; j++)
           {
            double current_gain = j / 10.0;
            double ec_trial = alpha * (ema_buffer[i] + current_gain * (m_price[i] - ec_prev)) + (1.0 - alpha) * ec_prev;
            double error = m_price[i] - ec_trial;
            if(fabs(error) < least_error)
              {
               least_error = fabs(error);
               best_gain = current_gain;
              }
           }

         // Calculate the final ZLEMA (EC) with the BestGain
         zlema_buffer[i] = alpha * (ema_buffer[i] + best_gain * (m_price[i] - ec_prev)) + (1.0 - alpha) * ec_prev;
         ec_prev = zlema_buffer[i];
        }
     }
  }

//+------------------------------------------------------------------+
bool CZeroLagEMACalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CZeroLagEMACalculator_HA : public CZeroLagEMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CZeroLagEMACalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
