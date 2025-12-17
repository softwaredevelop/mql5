//+------------------------------------------------------------------+
//|                                 LinearRegression_Calculator.mqh  |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Enum for Channel Calculation Mode ---
enum ENUM_CHANNEL_MODE
  {
   DEVIATION_STANDARD, // Channel width based on Standard Deviation
   DEVIATION_MAXIMUM   // Channel width based on Maximum Deviation
  };

//+==================================================================+
//|         CLASS 1: CLinearRegressionCalculator (Base Class)        |
//+==================================================================+
class CLinearRegressionCalculator
  {
protected:
   int               m_period;
   ENUM_CHANNEL_MODE m_channel_mode;
   double            m_deviations;

   //--- Persistent Buffer for Incremental Calculation
   double            m_price[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CLinearRegressionCalculator(void) {};
   virtual          ~CLinearRegressionCalculator(void) {};

   bool              Init(int period, ENUM_CHANNEL_MODE mode, double deviations);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLinearRegressionCalculator::Init(int period, ENUM_CHANNEL_MODE mode, double deviations)
  {
   m_period       = (period < 2) ? 2 : period;
   m_channel_mode = mode;
   m_deviations   = (deviations <= 0) ? 2.0 : deviations;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CLinearRegressionCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
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
   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Calculate Linear Regression (Always recalculate for the window)
   int regression_start_index = rates_total - m_period;
// Calculate Sums
   double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;
   for(int i = 0; i < m_period; i++)
     {
      double y = m_price[regression_start_index + i];
      double x = i;
      sum_x += x;
      sum_y += y;
      sum_xy += x * y;
      sum_x2 += x * x;
     }

   double b = (m_period * sum_xy - sum_x * sum_y) / (m_period * sum_x2 - sum_x * sum_x);
   double a = (sum_y - b * sum_x) / m_period;

   double deviation_offset = 0;
   double regression_values[];
   ArrayResize(regression_values, m_period);

   if(m_channel_mode == DEVIATION_STANDARD)
     {
      double dev_sum_sq = 0;
      for(int i = 0; i < m_period; i++)
        {
         regression_values[i] = a + b * i;
         dev_sum_sq += MathPow(m_price[regression_start_index + i] - regression_values[i], 2);
        }
      deviation_offset = m_deviations * MathSqrt(dev_sum_sq / m_period);
     }
   else // DEVIATION_MAXIMUM
     {
      double max_dev = 0;
      for(int i = 0; i < m_period; i++)
        {
         regression_values[i] = a + b * i;
         max_dev = MathMax(max_dev, MathAbs(m_price[regression_start_index + i] - regression_values[i]));
        }
      deviation_offset = max_dev;
     }

// Fill Buffers
   for(int i = 0; i < m_period; i++)
     {
      int buffer_index = regression_start_index + i;
      middle_buffer[buffer_index] = regression_values[i];
      upper_buffer[buffer_index]  = regression_values[i] + deviation_offset;
      lower_buffer[buffer_index]  = regression_values[i] - deviation_offset;
     }
   if(regression_start_index > 0)
     {
      middle_buffer[regression_start_index-1] = EMPTY_VALUE;
      upper_buffer[regression_start_index-1] = EMPTY_VALUE;
      lower_buffer[regression_start_index-1] = EMPTY_VALUE;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CLinearRegressionCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|             CLASS 2: CLinearRegressionCalculator_HA              |
//+==================================================================+
class CLinearRegressionCalculator_HA : public CLinearRegressionCalculator
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
bool CLinearRegressionCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
