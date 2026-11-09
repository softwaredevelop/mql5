//+------------------------------------------------------------------+
//|                                                RSI_Engine.mqh    |
//|      Core engine for Wilder's RSI calculation.                   |
//|      VERSION 2.00: Fused Multiply-Add & Fast Math Optimization   |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.00" // Enterprise Edition: Zero-Division Shield & FMA Reciprocals

#ifndef RSI_ENGINE_MQH
#define RSI_ENGINE_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//| CLASS 1: CRSIEngine (Base Class)                                 |
//+==================================================================+
class CRSIEngine
  {
protected:
   int               m_period;
   double            m_inv_period;
   double            m_alpha;
   double            m_beta;

   //--- Persistent State Buffers
   double            m_price[];
   double            m_avg_gain[];
   double            m_avg_loss[];

   //--- Virtual Prepare (Standard vs HA)
   virtual void      PrepareData(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
                                 const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CRSIEngine(void);
   virtual          ~CRSIEngine(void) {}

   bool              Init(const int period);
   int               GetPeriod(void) const { return m_period; }

   //--- Main Calculation (Strictly Chronological)
   void              Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &rsi_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRSIEngine::CRSIEngine(void) : m_period(14),
   m_inv_period(1.0 / 14.0),
   m_alpha(1.0 / 14.0),
   m_beta(13.0 / 14.0)
  {
   ArraySetAsSeries(m_price,    false);
   ArraySetAsSeries(m_avg_gain, false);
   ArraySetAsSeries(m_avg_loss, false);
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CRSIEngine::Init(const int period)
  {
   m_period     = (period < 1) ? 1 : period;
   m_inv_period = 1.0 / (double)m_period;
   m_alpha      = m_inv_period;
   m_beta       = (double)(m_period - 1) * m_inv_period;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Numerically Optimized & Zero Division Proof)   |
//+------------------------------------------------------------------+
void CRSIEngine::Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                           const double &open[], const double &high[], const double &low[], const double &close[],
                           double &rsi_buffer[])
  {
   if(rates_total <= m_period)
      return;

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// Resize working buffers with memory reservation capacity
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price,    rates_total, 2048);
      ArrayResize(m_avg_gain, rates_total, 2048);
      ArrayResize(m_avg_loss, rates_total, 2048);

      ArraySetAsSeries(m_price,    false);
      ArraySetAsSeries(m_avg_gain, false);
      ArraySetAsSeries(m_avg_loss, false);
     }

// Prepare Raw Price Vector
   PrepareData(rates_total, start_index, price_type, open, high, low, close);

   int i = start_index;
   if(i == 0)
     {
      m_avg_gain[0] = 0.0;
      m_avg_loss[0] = 0.0;
      rsi_buffer[0] = 50.0;
      i = 1;
     }

   for(; i < rates_total; i++)
     {
      double diff = m_price[i] - m_price[i - 1];
      double pos  = (diff > 0.0) ? diff : 0.0;
      double neg  = (diff < 0.0) ? -diff : 0.0;

      if(i < m_period)
        {
         m_avg_gain[i] = m_avg_gain[i - 1] + pos;
         m_avg_loss[i] = m_avg_loss[i - 1] + neg;
         rsi_buffer[i] = 50.0;
        }
      else
         if(i == m_period) // Initial SMA Seed
           {
            m_avg_gain[i] = (m_avg_gain[i - 1] + pos) * m_inv_period;
            m_avg_loss[i] = (m_avg_loss[i - 1] + neg) * m_inv_period;

            double sum_gl = m_avg_gain[i] + m_avg_loss[i];
            rsi_buffer[i] = (sum_gl > 0.0) ? ((100.0 * m_avg_gain[i]) / sum_gl) : 50.0;
           }
         else // Wilder's Smoothed RMA (Pipelined Multiply-Add)
           {
            m_avg_gain[i] = m_avg_gain[i - 1] * m_beta + pos * m_alpha;
            m_avg_loss[i] = m_avg_loss[i - 1] * m_beta + neg * m_alpha;

            double sum_gl = m_avg_gain[i] + m_avg_loss[i];
            rsi_buffer[i] = (sum_gl > 0.0) ? ((100.0 * m_avg_gain[i]) / sum_gl) : 50.0;
           }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Data (Standard - ALU Multiplication Optimized)           |
//+------------------------------------------------------------------+
void CRSIEngine::PrepareData(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
                             const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (high[i] + low[i]) * 0.5;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i] + low[i] + close[i]) * 0.3333333333333333;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i] + low[i] + 2.0 * close[i]) * 0.25;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
  }

//+==================================================================+
//| CLASS 2: CRSIEngine_HA (Heikin Ashi Specialization)              |
//+==================================================================+
class CRSIEngine_HA : public CRSIEngine
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double                 m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual void      PrepareData(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
                                 const double &open[], const double &high[], const double &low[], const double &close[]) override;

public:
                     CRSIEngine_HA(void)
     {
      ArraySetAsSeries(m_ha_open,  false);
      ArraySetAsSeries(m_ha_high,  false);
      ArraySetAsSeries(m_ha_low,   false);
      ArraySetAsSeries(m_ha_close, false);
     }
  };

//+------------------------------------------------------------------+
//| Prepare Data (Heikin Ashi - ALU Optimized)                       |
//+------------------------------------------------------------------+
void CRSIEngine_HA::PrepareData(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
                                const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open,  rates_total, 2048);
      ArrayResize(m_ha_high,  rates_total, 2048);
      ArrayResize(m_ha_low,   rates_total, 2048);
      ArrayResize(m_ha_close, rates_total, 2048);

      ArraySetAsSeries(m_ha_open,  false);
      ArraySetAsSeries(m_ha_high,  false);
      ArraySetAsSeries(m_ha_low,   false);
      ArraySetAsSeries(m_ha_close, false);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

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
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) * 0.5;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) * 0.3333333333333333;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) * 0.25;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
  }

#endif // RSI_ENGINE_MQH
//+------------------------------------------------------------------+
