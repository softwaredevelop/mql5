//+------------------------------------------------------------------+
//|                                                 Holt_Engine.mqh  |
//|        Core calculation engine for all Holt-based indicators.    |
//|      VERSION 2.10: Restored Trend/Level outputs.                 |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CHoltEngine (Base Class)                    |
//+==================================================================+
class CHoltEngine
  {
protected:
   int               m_period;
   double            m_alpha;
   double            m_beta;
   int               m_forecast_period;

   //--- Persistent Buffers
   double            m_price[];
   double            m_level[];
   double            m_trend[];

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CHoltEngine(void);
   virtual          ~CHoltEngine(void) {};

   bool              Init(int period, double alpha, double beta, int forecast_p);

   //--- Updated: Added trend_out and level_out back to signature
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &forecast_out[], double &trend_out[], double &level_out[], double &upper_band_out[], double &lower_band_out[]);
  };

//+------------------------------------------------------------------+
//| CHoltEngine: Constructor                                         |
//+------------------------------------------------------------------+
CHoltEngine::CHoltEngine(void) : m_period(0), m_alpha(0.1), m_beta(0.05), m_forecast_period(5)
  {
  }

//+------------------------------------------------------------------+
//| CHoltEngine: Initialization                                      |
//+------------------------------------------------------------------+
bool CHoltEngine::Init(int period, double alpha, double beta, int forecast_p)
  {
   m_period          = 10; // Safe minimum
   m_alpha           = (alpha <= 0) ? 0.1 : (alpha > 1) ? 1.0 : alpha;
   m_beta            = (beta <= 0) ? 0.05 : (beta > 1) ? 1.0 : beta;
   m_forecast_period = (forecast_p < 1) ? 1 : forecast_p;
   return true;
  }

//+------------------------------------------------------------------+
//| CHoltEngine: Main Calculation Method                             |
//+------------------------------------------------------------------+
void CHoltEngine::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                            double &forecast_out[], double &trend_out[], double &level_out[], double &upper_band_out[], double &lower_band_out[])
  {
   if(rates_total < 2)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_level, rates_total);
      ArrayResize(m_trend, rates_total);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   int loop_start = MathMax(2, start_index);

   if(loop_start == 2)
     {
      m_level[0] = m_price[0];
      m_trend[0] = m_price[1] - m_price[0];
      forecast_out[0] = m_level[0] + m_trend[0];

      m_level[1] = m_price[1];
      m_trend[1] = m_beta * (m_level[1] - m_level[0]) + (1 - m_beta) * m_trend[0];
      forecast_out[1] = m_level[1] + m_trend[1];

      // Fill outputs for first bars
      trend_out[0] = m_trend[0];
      level_out[0] = m_level[0];
      upper_band_out[0] = forecast_out[0];
      lower_band_out[0] = forecast_out[0];

      trend_out[1] = m_trend[1];
      level_out[1] = m_level[1];
      upper_band_out[1] = forecast_out[1];
      lower_band_out[1] = forecast_out[1];
     }

   for(int i = loop_start; i < rates_total; i++)
     {
      m_level[i] = m_alpha * m_price[i] + (1.0 - m_alpha) * (m_level[i-1] + m_trend[i-1]);
      m_trend[i] = m_beta * (m_level[i] - m_level[i-1]) + (1.0 - m_beta) * m_trend[i-1];

      forecast_out[i] = m_level[i] + m_trend[i];

      // Copy internal state to output buffers
      trend_out[i] = m_trend[i];
      level_out[i] = m_level[i];

      double width = m_forecast_period * MathAbs(m_trend[i]);
      upper_band_out[i] = forecast_out[i] + width;
      lower_band_out[i] = forecast_out[i] - width;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CHoltEngine::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|             CLASS 2: CHoltEngine_HA (Heikin Ashi)                |
//+==================================================================+
class CHoltEngine_HA : public CHoltEngine
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
bool CHoltEngine_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
