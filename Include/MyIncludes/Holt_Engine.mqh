//+------------------------------------------------------------------+
//|                                                 Holt_Engine.mqh  |
//|        Core calculation engine for all Holt-based indicators.    |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CHoltEngine (Base Class)                    |
//|                                                                  |
//+==================================================================+
class CHoltEngine
  {
protected:
   int               m_period;
   double            m_alpha;
   double            m_beta;
   int               m_forecast_period;

   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CHoltEngine(void);
   virtual          ~CHoltEngine(void) {};

   bool              Init(int period, double alpha, double beta, int forecast_p);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
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
   m_period          = (period < 2) ? 2 : period;
   m_alpha           = (alpha <= 0) ? 0.0001 : (alpha >= 1) ? 0.9999 : alpha;
   m_beta            = (beta <= 0) ? 0.0001 : (beta >= 1) ? 0.9999 : beta;
   m_forecast_period = (forecast_p < 1) ? 1 : forecast_p;
   return true;
  }

//+------------------------------------------------------------------+
//| CHoltEngine: Main Calculation Method                             |
//+------------------------------------------------------------------+
void CHoltEngine::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                            double &forecast_out[], double &trend_out[], double &level_out[], double &upper_band_out[], double &lower_band_out[])
  {
   if(rates_total < m_period)
      return;

   ArrayResize(m_price, rates_total);
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   level_out[0] = m_price[0];
   trend_out[0] = m_price[1] - m_price[0];
   forecast_out[0] = level_out[0] + trend_out[0];
   level_out[1] = m_price[1];
   trend_out[1] = m_beta * (level_out[1] - level_out[0]) + (1 - m_beta) * trend_out[0];
   forecast_out[1] = level_out[1] + trend_out[1];

   for(int i = 2; i < rates_total; i++)
     {
      level_out[i] = m_alpha * m_price[i] + (1 - m_alpha) * (level_out[i-1] + trend_out[i-1]);
      trend_out[i] = m_beta * (level_out[i] - level_out[i-1]) + (1 - m_beta) * trend_out[i-1];
      forecast_out[i] = level_out[i] + trend_out[i];
      upper_band_out[i] = level_out[i] + m_forecast_period * trend_out[i];
      lower_band_out[i] = level_out[i] - m_forecast_period * trend_out[i];
     }
  }

//+------------------------------------------------------------------+
//| CHoltEngine: Prepares the standard source price series.          |
//+------------------------------------------------------------------+
bool CHoltEngine::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   switch(price_type)
     {
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
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
     }
   return true;
  }

//+==================================================================+
//|                                                                  |
//|             CLASS 2: CHoltEngine_HA (Heikin Ashi)                |
//|                                                                  |
//+==================================================================+
class CHoltEngine_HA : public CHoltEngine
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CHoltEngine_HA: Prepares the Heikin Ashi source price.           |
//+------------------------------------------------------------------+
bool CHoltEngine_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   switch(price_type)
     {
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
            m_price[i] = (ha_high[i]+ha_low[i]+2*ha_close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
