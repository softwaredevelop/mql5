//+------------------------------------------------------------------+
//|                                     ZeroLag_EMA_Calculator.mqh   |
//|      Calculation engine for the John Ehlers' Zero-Lag EMA.       |
//|      VERSION 3.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CZeroLagEMACalculator (Base Class)          |
//+==================================================================+
class CZeroLagEMACalculator
  {
protected:
   int               m_period;
   bool              m_optimize_gain;
   double            m_gain_limit;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];

   //--- State Buffers for Standard Mode
   double            m_ema1[];
   double            m_ema2[];

   //--- State Buffers for Optimized Gain Mode
   double            m_ema[];
   double            m_ec[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CZeroLagEMACalculator(void) {};
   virtual          ~CZeroLagEMACalculator(void) {};

   bool              Init(int period, bool optimize_gain, double gain_limit);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &zlema_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CZeroLagEMACalculator::Init(int period, bool optimize_gain, double gain_limit)
  {
   m_period = (period < 1) ? 1 : period;
   m_optimize_gain = optimize_gain;
   m_gain_limit = gain_limit;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CZeroLagEMACalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &zlema_buffer[])
  {
   if(rates_total < m_period * 2)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      if(!m_optimize_gain)
        {
         ArrayResize(m_ema1, rates_total);
         ArrayResize(m_ema2, rates_total);
        }
      else
        {
         ArrayResize(m_ema, rates_total);
         ArrayResize(m_ec, rates_total);
        }
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   double alpha = 2.0 / (m_period + 1.0);

   if(!m_optimize_gain)
     {
      // --- Standard (Double EMA) Zero-Lag EMA Calculation ---
      int loop_start = MathMax(m_period, start_index);

      // Initialization
      if(loop_start == m_period)
        {
         double sum=0;
         for(int j=0; j<m_period; j++)
            sum+=m_price[m_period-1-j];
         m_ema1[m_period-1] = sum/m_period;

         // For EMA2, we need more history, but let's init simply
         m_ema2[m_period-1] = m_ema1[m_period-1];
        }

      for(int i = loop_start; i < rates_total; i++)
        {
         // EMA1
         m_ema1[i] = m_price[i] * alpha + (1.0 - alpha) * m_ema1[i-1];

         // EMA2 (of EMA1)
         m_ema2[i] = m_ema1[i] * alpha + (1.0 - alpha) * m_ema2[i-1];

         // ZLEMA = 2*EMA1 - EMA2
         zlema_buffer[i] = 2.0 * m_ema1[i] - m_ema2[i];
        }
     }
   else
     {
      // --- Ehlers' Optimized Gain (Error Correcting) Calculation ---
      int loop_start = MathMax(1, start_index);

      if(loop_start == 1)
        {
         m_ema[0] = m_price[0];
         m_ec[0] = m_price[0];
         zlema_buffer[0] = m_price[0];
        }

      for(int i = loop_start; i < rates_total; i++)
        {
         // Calculate standard EMA first
         m_ema[i] = m_price[i] * alpha + (1.0 - alpha) * m_ema[i-1];

         // Find the BestGain for the current bar
         double least_error = 1e10;
         double best_gain = 0;
         int gain_steps = (int)(m_gain_limit * 10);
         double ec_prev = m_ec[i-1];

         for(int j = -gain_steps; j <= gain_steps; j++)
           {
            double current_gain = j / 10.0;
            double ec_trial = alpha * (m_ema[i] + current_gain * (m_price[i] - ec_prev)) + (1.0 - alpha) * ec_prev;
            double error = m_price[i] - ec_trial;
            if(fabs(error) < least_error)
              {
               least_error = fabs(error);
               best_gain = current_gain;
              }
           }

         // Calculate the final ZLEMA (EC) with the BestGain
         m_ec[i] = alpha * (m_ema[i] + best_gain * (m_price[i] - ec_prev)) + (1.0 - alpha) * ec_prev;
         zlema_buffer[i] = m_ec[i];
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CZeroLagEMACalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|             CLASS 2: CZeroLagEMACalculator_HA                    |
//+==================================================================+
class CZeroLagEMACalculator_HA : public CZeroLagEMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];
protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CZeroLagEMACalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_ha_high, m_ha_low, m_ha_close);

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
