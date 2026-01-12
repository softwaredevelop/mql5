//+------------------------------------------------------------------+
//|                                                RSI_Engine.mqh    |
//|      Core engine for Wilder's RSI calculation.                   |
//|      VERSION 1.00                                                |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CRSIEngine (Base Class)                     |
//+==================================================================+
class CRSIEngine
  {
protected:
   int               m_period;

   //--- Persistent Buffers
   double            m_price[];
   double            m_avg_gain[];
   double            m_avg_loss[];

   //--- Virtual Prepare (Standard vs HA)
   virtual void      PrepareData(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CRSIEngine(void) {};
   virtual          ~CRSIEngine(void) {};

   bool              Init(int period);
   int               GetPeriod(void) const { return m_period; }

   //--- Main Calculation
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &rsi_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CRSIEngine::Init(int period)
  {
   m_period = (period < 1) ? 1 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CRSIEngine::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                           double &rsi_buffer[])
  {
   if(rates_total <= m_period)
      return;

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_avg_gain, rates_total);
      ArrayResize(m_avg_loss, rates_total);
     }

// 1. Prepare Data
   PrepareData(rates_total, start_index, price_type, open, high, low, close);

// 2. Calculate RSI
   int i = start_index;
   if(i == 0)
     {
      m_avg_gain[0] = 0;
      m_avg_loss[0] = 0;
      rsi_buffer[0] = 0;
      i = 1;
     }

   for(; i < rates_total; i++)
     {
      double diff = m_price[i] - m_price[i-1];
      double pos = (diff > 0 ? diff : 0);
      double neg = (diff < 0 ? -diff : 0);

      if(i <= m_period)
        {
         if(i < m_period)
           {
            m_avg_gain[i] = m_avg_gain[i-1] + pos;
            m_avg_loss[i] = m_avg_loss[i-1] + neg;
            rsi_buffer[i] = 0;
           }
         else // i == m_period (Initial SMA)
           {
            m_avg_gain[i] = (m_avg_gain[i-1] + pos) / m_period;
            m_avg_loss[i] = (m_avg_loss[i-1] + neg) / m_period;

            if(m_avg_loss[i] > 0)
               rsi_buffer[i] = 100.0 - (100.0 / (1.0 + (m_avg_gain[i] / m_avg_loss[i])));
            else
               rsi_buffer[i] = 100.0;
           }
        }
      else // Wilder's Smoothing (RMA)
        {
         m_avg_gain[i] = (m_avg_gain[i-1] * (m_period - 1) + pos) / m_period;
         m_avg_loss[i] = (m_avg_loss[i-1] * (m_period - 1) + neg) / m_period;

         if(m_avg_loss[i] > 0)
            rsi_buffer[i] = 100.0 - (100.0 / (1.0 + (m_avg_gain[i] / m_avg_loss[i])));
         else
            rsi_buffer[i] = 100.0;
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Data (Standard)                                          |
//+------------------------------------------------------------------+
void CRSIEngine::PrepareData(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
  }

//+==================================================================+
//|             CLASS 2: CRSIEngine_HA (Heikin Ashi)                 |
//+==================================================================+
class CRSIEngine_HA : public CRSIEngine
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual void      PrepareData(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Data (Heikin Ashi)                                       |
//+------------------------------------------------------------------+
void CRSIEngine_HA::PrepareData(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
