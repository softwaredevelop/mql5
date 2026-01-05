//+------------------------------------------------------------------+
//|                                     Windowed_MA_Calculator.mqh   |
//|      Calculation engine for Hann Windowed FIR filter.            |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

enum ENUM_INPUT_SOURCE { SOURCE_PRICE, SOURCE_MOMENTUM }; // Price or (Close-Open)

//+==================================================================+
//|             CLASS 1: CWindowedMACalculator (Base Class)          |
//+==================================================================+
class CWindowedMACalculator
  {
protected:
   int                 m_period;
   ENUM_INPUT_SOURCE   m_source_type;

   //--- Persistent Buffer for Incremental Calculation
   double              m_source_data[];

   //--- Pre-calculated Weights
   double              m_weights[];
   double              m_weight_sum;

   //--- Updated: Accepts start_index
   virtual bool      PrepareSourceData(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CWindowedMACalculator(void) {};
   virtual          ~CWindowedMACalculator(void) {};

   bool              Init(int period, ENUM_INPUT_SOURCE source_type);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &output_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CWindowedMACalculator::Init(int period, ENUM_INPUT_SOURCE source_type)
  {
   m_period = (period < 2) ? 2 : period;
   m_source_type = source_type;

// Pre-calculate Hann Weights
   ArrayResize(m_weights, m_period);
   m_weight_sum = 0;

   for(int j = 0; j < m_period; j++)
     {
      // Hann Window Formula: 0.5 * (1 - cos(2*pi*j / (N-1)))
      // Note: j goes from 0 to N-1.
      // j=0 -> weight=0
      // j=N-1 -> weight=0
      // Peak is at j=(N-1)/2

      double weight = 0.5 * (1.0 - cos(2.0 * M_PI * j / (m_period - 1.0)));
      m_weights[j] = weight;
      m_weight_sum += weight;
     }

   return (m_weight_sum > 0);
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CWindowedMACalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &output_buffer[])
  {
   if(rates_total < m_period)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffer
   if(ArraySize(m_source_data) != rates_total)
      ArrayResize(m_source_data, rates_total);

//--- 3. Prepare Source Data (Optimized)
   if(!PrepareSourceData(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Calculate Windowed MA (Incremental Loop)
   int loop_start = MathMax(m_period - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double sum = 0;

      // Convolution: Sum(Price[i-j] * Weight[j])
      // Optimization: Weights are pre-calculated
      for(int j = 0; j < m_period; j++)
        {
         sum += m_source_data[i-j] * m_weights[j];
        }

      output_buffer[i] = sum / m_weight_sum;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Source Data (Standard - Optimized)                       |
//+------------------------------------------------------------------+
bool CWindowedMACalculator::PrepareSourceData(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      if(m_source_type == SOURCE_PRICE)
        {
         switch(price_type)
           {
            case PRICE_CLOSE:
               m_source_data[i] = close[i];
               break;
            case PRICE_OPEN:
               m_source_data[i] = open[i];
               break;
            case PRICE_HIGH:
               m_source_data[i] = high[i];
               break;
            case PRICE_LOW:
               m_source_data[i] = low[i];
               break;
            case PRICE_MEDIAN:
               m_source_data[i] = (high[i]+low[i])/2.0;
               break;
            case PRICE_TYPICAL:
               m_source_data[i] = (high[i]+low[i]+close[i])/3.0;
               break;
            case PRICE_WEIGHTED:
               m_source_data[i] = (high[i]+low[i]+2*close[i])/4.0;
               break;
            default:
               m_source_data[i] = close[i];
               break;
           }
        }
      else // SOURCE_MOMENTUM
        {
         m_source_data[i] = close[i] - open[i];
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CWindowedMACalculator_HA (Heikin Ashi)      |
//+==================================================================+
class CWindowedMACalculator_HA : public CWindowedMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Source Data (Heikin Ashi - Optimized)                    |
//+------------------------------------------------------------------+
bool CWindowedMACalculator_HA::PrepareSourceData(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
      if(m_source_type == SOURCE_PRICE)
        {
         switch(price_type)
           {
            case PRICE_CLOSE:
               m_source_data[i] = m_ha_close[i];
               break;
            case PRICE_OPEN:
               m_source_data[i] = m_ha_open[i];
               break;
            case PRICE_HIGH:
               m_source_data[i] = m_ha_high[i];
               break;
            case PRICE_LOW:
               m_source_data[i] = m_ha_low[i];
               break;
            case PRICE_MEDIAN:
               m_source_data[i] = (m_ha_high[i]+m_ha_low[i])/2.0;
               break;
            case PRICE_TYPICAL:
               m_source_data[i] = (m_ha_high[i]+m_ha_low[i]+m_ha_close[i])/3.0;
               break;
            case PRICE_WEIGHTED:
               m_source_data[i] = (m_ha_high[i]+m_ha_low[i]+2*m_ha_close[i])/4.0;
               break;
            default:
               m_source_data[i] = m_ha_close[i];
               break;
           }
        }
      else // SOURCE_MOMENTUM
        {
         m_source_data[i] = m_ha_close[i] - m_ha_open[i];
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
