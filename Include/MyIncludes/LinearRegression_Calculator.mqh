//+------------------------------------------------------------------+
//|                                 LinearRegression_Calculator.mqh  |
//| Calculation engine for Standard and Heikin Ashi LinReg Channels. |
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
//|                                                                  |
//|         CLASS 1: CLinearRegressionCalculator (Base Class)        |
//|                                                                  |
//+==================================================================+
class CLinearRegressionCalculator
  {
protected:
   int               m_period;
   ENUM_CHANNEL_MODE m_channel_mode;
   double            m_deviations;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

public:
                     CLinearRegressionCalculator(void) {};
   virtual          ~CLinearRegressionCalculator(void) {};

   bool              Init(int period, ENUM_CHANNEL_MODE mode, double deviations);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);
  };

//+------------------------------------------------------------------+
//| CLinearRegressionCalculator: Initialization                      |
//+------------------------------------------------------------------+
bool CLinearRegressionCalculator::Init(int period, ENUM_CHANNEL_MODE mode, double deviations)
  {
   m_period       = (period < 2) ? 2 : period;
   m_channel_mode = mode;
   m_deviations   = (deviations <= 0) ? 2.0 : deviations;
   return true;
  }

//+------------------------------------------------------------------+
//| CLinearRegressionCalculator: Main Calculation Method             |
//+------------------------------------------------------------------+
void CLinearRegressionCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   if(rates_total < m_period)
      return;
   if(!PreparePriceSeries(rates_total, open, high, low, close, price_type))
      return;

   int start_index = rates_total - m_period;
   double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;
   for(int i = 0; i < m_period; i++)
     {
      double y = m_price[start_index + i];
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
         dev_sum_sq += MathPow(m_price[start_index + i] - regression_values[i], 2);
        }
      deviation_offset = m_deviations * MathSqrt(dev_sum_sq / m_period);
     }
   else // DEVIATION_MAXIMUM
     {
      double max_dev = 0;
      for(int i = 0; i < m_period; i++)
        {
         regression_values[i] = a + b * i;
         max_dev = MathMax(max_dev, MathAbs(m_price[start_index + i] - regression_values[i]));
        }
      deviation_offset = max_dev;
     }

   for(int i = 0; i < m_period; i++)
     {
      int buffer_index = start_index + i;
      middle_buffer[buffer_index] = regression_values[i];
      upper_buffer[buffer_index]  = regression_values[i] + deviation_offset;
      lower_buffer[buffer_index]  = regression_values[i] - deviation_offset;
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, start_index);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, start_index);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, start_index);
  }

//+------------------------------------------------------------------+
//| CLinearRegressionCalculator: Prepares the standard source price. |
//+------------------------------------------------------------------+
bool CLinearRegressionCalculator::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   ArrayResize(m_price, rates_total);
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
//|       CLASS 2: CLinearRegressionCalculator_HA (Heikin Ashi)      |
//|                                                                  |
//+==================================================================+
class CLinearRegressionCalculator_HA : public CLinearRegressionCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| CLinearRegressionCalculator_HA: Prepares the HA source price.    |
//+------------------------------------------------------------------+
bool CLinearRegressionCalculator_HA::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_price, rates_total);
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
