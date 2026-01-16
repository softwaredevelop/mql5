//+------------------------------------------------------------------+
//|                                  Laguerre_Bands_Calculator.mqh   |
//|      Laguerre Filter Middle Line + StdDev Bands (Bollinger).     |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\Laguerre_Engine.mqh>

//+==================================================================+
//|           CLASS 1: CLaguerreBandsCalculator (Base)               |
//+==================================================================+
class CLaguerreBandsCalculator
  {
protected:
   int               m_period;
   double            m_deviation;

   //--- Composition
   CLaguerreEngine   *m_laguerre_engine;

   //--- Persistent Buffers
   double            m_price[]; // Need local copy for StdDev calculation

   //--- Virtual Price Preparation
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

   virtual void      CreateEngine(void);

public:
                     CLaguerreBandsCalculator(void);
   virtual          ~CLaguerreBandsCalculator(void);

   bool              Init(double gamma, int period, double deviation);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreBandsCalculator::CLaguerreBandsCalculator(void)
  {
   m_laguerre_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreBandsCalculator::~CLaguerreBandsCalculator(void)
  {
   if(CheckPointer(m_laguerre_engine) != POINTER_INVALID)
      delete m_laguerre_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CLaguerreBandsCalculator::CreateEngine(void)
  {
   m_laguerre_engine = new CLaguerreEngine();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreBandsCalculator::Init(double gamma, int period, double deviation)
  {
   m_period = (period < 2) ? 2 : period;
   m_deviation = deviation;

   CreateEngine(); // Creates Laguerre Engine

   if(CheckPointer(m_laguerre_engine) == POINTER_INVALID || !m_laguerre_engine.Init(gamma, SOURCE_PRICE))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CLaguerreBandsCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   if(rates_total < m_period)
      return;

//--- 1. Determine Start Index
   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

//--- 2. Resize Internal Buffer
   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);

//--- 3. Prepare Price (For StdDev calculation)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Calculate Middle Line (Laguerre)
// Note: The engine handles its own price preparation internally, but that's fine.
   m_laguerre_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, middle_buffer);

//--- 5. Calculate Bands (StdDev from Laguerre)
   int loop_start = MathMax(m_period, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double sum_sq = 0;

      // Calculate Standard Deviation relative to the Laguerre Middle Line
      for(int j = 0; j < m_period; j++)
        {
         double diff = m_price[i-j] - middle_buffer[i];
         sum_sq += diff * diff;
        }

      double std_dev = sqrt(sum_sq / m_period);

      upper_buffer[i] = middle_buffer[i] + (std_dev * m_deviation);
      lower_buffer[i] = middle_buffer[i] - (std_dev * m_deviation);
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard)                                         |
//+------------------------------------------------------------------+
bool CLaguerreBandsCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (high[i] + low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i] + low[i] + 2 * close[i]) / 4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|           CLASS 2: CLaguerreBandsCalculator_HA                   |
//+==================================================================+
class CLaguerreBandsCalculator_HA : public CLaguerreBandsCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual void      CreateEngine(void) override;
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Factory Override                                                 |
//+------------------------------------------------------------------+
void CLaguerreBandsCalculator_HA::CreateEngine(void)
  {
   m_laguerre_engine = new CLaguerreEngine_HA();
  }

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi)                                      |
//+------------------------------------------------------------------+
bool CLaguerreBandsCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
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
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2 * m_ha_close[i]) / 4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
