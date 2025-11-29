//+------------------------------------------------------------------+
//|                                    Ehlers_Bands_Calculator.mqh   |
//|      VERSION 1.20: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>

//+==================================================================+
class CEhlersBandsCalculator
  {
protected:
   CEhlersSmootherCalculator *m_calc_center;
   int               m_period;
   double            m_multiplier;

   //--- Persistent Buffer for Price
   double            m_price[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CEhlersBandsCalculator(void);
   virtual          ~CEhlersBandsCalculator(void);

   bool              Init(int period, double multiplier, ENUM_SMOOTHER_TYPE smoother_type);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &upper_buffer[], double &lower_buffer[], double &middle_buffer[]);
  };

//+------------------------------------------------------------------+
CEhlersBandsCalculator::CEhlersBandsCalculator(void)
  {
   m_calc_center = NULL;
  }
//+------------------------------------------------------------------+
CEhlersBandsCalculator::~CEhlersBandsCalculator(void)
  {
   if(CheckPointer(m_calc_center) != POINTER_INVALID)
      delete m_calc_center;
  }
//+------------------------------------------------------------------+
bool CEhlersBandsCalculator::Init(int period, double multiplier, ENUM_SMOOTHER_TYPE smoother_type)
  {
   m_period = (period < 2) ? 2 : period;
   m_multiplier = multiplier;

   if(CheckPointer(m_calc_center) == POINTER_INVALID)
      m_calc_center = new CEhlersSmootherCalculator();

   if(CheckPointer(m_calc_center) == POINTER_INVALID)
      return false;

   return(m_calc_center.Init(m_period, smoother_type, SOURCE_PRICE));
  }

//+------------------------------------------------------------------+
void CEhlersBandsCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                       double &upper_buffer[], double &lower_buffer[], double &middle_buffer[])
  {
   if(rates_total < m_period)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Internal Buffer
   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Calculate Centerline (Incremental)
   m_calc_center.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, middle_buffer);

//--- 5. Calculate Bands (Incremental Loop)
   int loop_start = MathMax(m_period - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double sum_sq = 0;
      for(int j = 0; j < m_period; j++)
        {
         double diff = m_price[i-j] - middle_buffer[i-j];
         sum_sq += diff * diff;
        }

      double std_dev = sqrt(sum_sq / m_period);

      if(middle_buffer[i] != EMPTY_VALUE)
        {
         upper_buffer[i] = middle_buffer[i] + m_multiplier * std_dev;
         lower_buffer[i] = middle_buffer[i] - m_multiplier * std_dev;
        }
     }
  }

//+------------------------------------------------------------------+
bool CEhlersBandsCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Optimized copy loop
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
class CEhlersBandsCalculator_HA : public CEhlersBandsCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

public:
                     CEhlersBandsCalculator_HA(void)
     {
      if(CheckPointer(m_calc_center) != POINTER_INVALID)
         delete m_calc_center;
      m_calc_center = new CEhlersSmootherCalculator_HA();
     }
protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CEhlersBandsCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
