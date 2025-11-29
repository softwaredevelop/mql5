//+------------------------------------------------------------------+
//|                                   Ehlers_Smoother_Calculator.mqh |
//|      VERSION 2.40: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

enum ENUM_SMOOTHER_TYPE { SUPERSMOOTHER, ULTIMATESMOOTHER };
enum ENUM_INPUT_SOURCE { SOURCE_PRICE, SOURCE_MOMENTUM };

//+==================================================================+
class CEhlersSmootherCalculator
  {
protected:
   int                 m_period;
   ENUM_SMOOTHER_TYPE  m_type;
   ENUM_INPUT_SOURCE   m_source_type;

   //--- Persistent Buffer for Price
   double              m_price[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CEhlersSmootherCalculator(void) {};
   virtual          ~CEhlersSmootherCalculator(void) {};

   bool              Init(int period, ENUM_SMOOTHER_TYPE type, ENUM_INPUT_SOURCE source_type);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[]);

   int               GetPeriod(void) const { return m_period; }
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CEhlersSmootherCalculator::Init(int period, ENUM_SMOOTHER_TYPE type, ENUM_INPUT_SOURCE source_type)
  {
   m_period = (period < 2) ? 2 : period;
   m_type = type;
   m_source_type = source_type;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CEhlersSmootherCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[])
  {
   if(rates_total < 4)
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

//--- 4. Calculate Coefficients
   double a1 = exp(-M_SQRT2 * M_PI / m_period);
   double b1 = 2.0 * a1 * cos(M_SQRT2 * M_PI / m_period);
   double c2 = b1;
   double c3 = -a1 * a1;
   double c1 = (m_type == SUPERSMOOTHER) ? (1.0 - c2 - c3) : ((1.0 + c2 - c3) / 4.0);

//--- 5. Calculate Filter (Incremental Loop)
   int i = start_index;

// Initialization for the first few bars
   if(i < 3)
     {
      if(rates_total > 0)
         filter_buffer[0] = m_price[0];
      if(rates_total > 1)
         filter_buffer[1] = m_price[1];
      if(rates_total > 2)
         filter_buffer[2] = m_price[2];
      i = 3;
     }

   for(; i < rates_total; i++)
     {
      double current_f = 0;

      // We use filter_buffer[i-1] and [i-2] which are persistent
      double f1 = filter_buffer[i-1];
      double f2 = filter_buffer[i-2];

      if(m_type == SUPERSMOOTHER)
         current_f = c1 * (m_price[i] + m_price[i-1]) / 2.0 + c2 * f1 + c3 * f2;
      else // ULTIMATESMOOTHER
         current_f = (1.0 - c1) * m_price[i] + (2.0 * c1 - c2) * m_price[i-1] - (c1 + c3) * m_price[i-2] + c2 * f1 + c3 * f2;

      filter_buffer[i] = current_f;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CEhlersSmootherCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Optimized copy loop
   for(int i = start_index; i < rates_total; i++)
     {
      if(m_source_type == SOURCE_PRICE)
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
      else // SOURCE_MOMENTUM
        {
         m_price[i] = close[i] - open[i];
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CEhlersSmootherCalculator_HA                |
//+==================================================================+
class CEhlersSmootherCalculator_HA : public CEhlersSmootherCalculator
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
bool CEhlersSmootherCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
      if(m_source_type == SOURCE_PRICE)
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
      else // SOURCE_MOMENTUM
        {
         m_price[i] = m_ha_close[i] - m_ha_open[i];
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
