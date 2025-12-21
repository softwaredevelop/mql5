//+------------------------------------------------------------------+
//|                                   Gaussian_Filter_Calculator.mqh |
//|      Calculation engine for the John Ehlers' Gaussian Filter.    |
//|      VERSION 3.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

enum ENUM_INPUT_SOURCE { SOURCE_PRICE, SOURCE_MOMENTUM };

//+==================================================================+
//|             CLASS 1: CGaussianFilterCalculator                   |
//+==================================================================+
class CGaussianFilterCalculator
  {
protected:
   int               m_period;
   ENUM_INPUT_SOURCE m_source_type;

   //--- Persistent Buffer for Price
   double            m_price[];

   //--- Filter coefficients
   double            c0, a1, a2;

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CGaussianFilterCalculator(void) {};
   virtual          ~CGaussianFilterCalculator(void) {};

   bool              Init(int period, ENUM_INPUT_SOURCE source_type);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CGaussianFilterCalculator::Init(int period, ENUM_INPUT_SOURCE source_type)
  {
   m_period = (period < 2) ? 2 : period;
   m_source_type = source_type;

// Calculate coefficients (Ehlers' formula)
   double beta = 2.415 * (1.0 - cos(2.0 * M_PI / m_period));
   double alpha = -beta + sqrt(beta * beta + 2.0 * beta);

   c0 = alpha * alpha;
   a1 = 2.0 * (1.0 - alpha);
   a2 = -pow(1.0 - alpha, 2);

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CGaussianFilterCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[])
  {
   if(rates_total < 3)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

// Resize internal buffer
   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- Incremental Loop
// We start at index 2 because we need i-1 and i-2
   int loop_start = MathMax(2, start_index);

// Initialization for the very first bars
   if(loop_start == 2)
     {
      filter_buffer[0] = m_price[0];
      filter_buffer[1] = m_price[1];
     }

   for(int i = loop_start; i < rates_total; i++)
     {
      // Recursive calculation: f[i] = c0*price[i] + a1*f[i-1] + a2*f[i-2]
      // We use filter_buffer directly for f[i-1] and f[i-2] because it persists between ticks.
      filter_buffer[i] = c0 * m_price[i] + a1 * filter_buffer[i-1] + a2 * filter_buffer[i-2];
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CGaussianFilterCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
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
//|             CLASS 2: CGaussianFilterCalculator_HA                |
//+==================================================================+
class CGaussianFilterCalculator_HA : public CGaussianFilterCalculator
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
bool CGaussianFilterCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
