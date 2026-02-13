//+------------------------------------------------------------------+
//|                                 LinearRegression_Calculator.mqh  |
//|      VERSION 4.00: Integrated R-Squared and Slope calculation.   |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

enum ENUM_CHANNEL_MODE
  {
   DEVIATION_STANDARD,
   DEVIATION_MAXIMUM
  };

//+==================================================================+
//|         CLASS: CLinearRegressionCalculator                       |
//+==================================================================+
class CLinearRegressionCalculator
  {
protected:
   int               m_period;
   ENUM_CHANNEL_MODE m_channel_mode;
   double            m_deviations;

   // Precalc for optimization
   double            m_sum_x, m_sum_x2;
   double            m_denom_x;

   //--- Persistent Buffer
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CLinearRegressionCalculator(void) {};
   virtual          ~CLinearRegressionCalculator(void) {};

   // Init 1: Full (For Channels)
   bool              Init(int period, ENUM_CHANNEL_MODE mode, double deviations);
   // Init 2: Simple (For R2/Slope only)
   bool              Init(int period);

   //--- Method 1: Moving Regression (The "Wavy" line)
   void              CalculateMoving(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                                     double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);

   //--- Method 2: Static Channel (The "Straight" segment for current bars)
   void              CalculateStaticChannel(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
         double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);

   //--- Method 3: Rolling Statistics (R-Squared & Slope) - NEW
   void              CalculateState(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                                    double &out_slope[], double &out_r2[], double &out_forecast[]);
  };

//+------------------------------------------------------------------+
//| Init (Full)                                                      |
//+------------------------------------------------------------------+
bool CLinearRegressionCalculator::Init(int period, ENUM_CHANNEL_MODE mode, double deviations)
  {
   m_period       = (period < 2) ? 2 : period;
   m_channel_mode = mode;
   m_deviations   = (deviations <= 0) ? 2.0 : deviations;

// Pre-calc X sums (0..N-1)
   m_sum_x = 0;
   m_sum_x2 = 0;
   for(int k = 0; k < m_period; k++)
     {
      m_sum_x += k;
      m_sum_x2 += k * k;
     }
   m_denom_x = m_period * m_sum_x2 - m_sum_x * m_sum_x;

   return true;
  }

//+------------------------------------------------------------------+
//| Init (Simple)                                                    |
//+------------------------------------------------------------------+
bool CLinearRegressionCalculator::Init(int period)
  {
   return Init(period, DEVIATION_STANDARD, 2.0); // Delegate with defaults
  }

//+------------------------------------------------------------------+
//| Method 1: Moving Regression (Wavy)                               |
//+------------------------------------------------------------------+
void CLinearRegressionCalculator::CalculateMoving(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   if(rates_total < m_period)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// Pre-calc X sums
   double sum_x = 0, sum_x2 = 0;
   for(int k = 0; k < m_period; k++)
     {
      sum_x += k;
      sum_x2 += k * k;
     }
   double denominator = m_period * sum_x2 - sum_x * sum_x;

   int loop_start = MathMax(m_period - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double sum_y = 0, sum_xy = 0;
      for(int k = 0; k < m_period; k++)
        {
         double price = m_price[i - m_period + 1 + k];
         sum_y += price;
         sum_xy += k * price;
        }

      double b = (m_period * sum_xy - sum_x * sum_y) / denominator;
      double a = (sum_y - b * sum_x) / m_period;
      double regression_value = a + b * (m_period - 1); // End point

      middle_buffer[i] = regression_value;

      double deviation_offset = 0;
      if(m_channel_mode == DEVIATION_STANDARD)
        {
         double dev_sum_sq = 0;
         for(int k = 0; k < m_period; k++)
           {
            double price = m_price[i - m_period + 1 + k];
            double reg_val_at_k = a + b * k;
            dev_sum_sq += MathPow(price - reg_val_at_k, 2);
           }
         deviation_offset = m_deviations * MathSqrt(dev_sum_sq / m_period);
        }
      else
        {
         double max_dev = 0;
         for(int k = 0; k < m_period; k++)
           {
            double price = m_price[i - m_period + 1 + k];
            double reg_val_at_k = a + b * k;
            max_dev = MathMax(max_dev, MathAbs(price - reg_val_at_k));
           }
         deviation_offset = max_dev;
        }

      upper_buffer[i] = regression_value + deviation_offset;
      lower_buffer[i] = regression_value - deviation_offset;
     }
  }

//+------------------------------------------------------------------+
//| Method 2: Static Channel (Straight)                              |
//+------------------------------------------------------------------+
void CLinearRegressionCalculator::CalculateStaticChannel(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   if(rates_total < m_period)
      return;

// Always update price buffer for the last segment
   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);

// We only need to prepare the last 'm_period' prices
   int start_prep = rates_total - m_period;
   if(!PreparePriceSeries(rates_total, start_prep, price_type, open, high, low, close))
      return;

// 1. Clear old history (Optimization: only clear if necessary, but for visual clarity we clear all before start)
   if(start_prep > 0)
     {
      middle_buffer[start_prep - 1] = EMPTY_VALUE;
      upper_buffer[start_prep - 1]  = EMPTY_VALUE;
      lower_buffer[start_prep - 1]  = EMPTY_VALUE;
     }

// 2. Calculate Regression for the SINGLE window [rates_total-period ... rates_total-1]
   double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;

   for(int k = 0; k < m_period; k++)
     {
      double x = k;
      double y = m_price[start_prep + k];
      sum_x += x;
      sum_x2 += x * x;
      sum_y += y;
      sum_xy += x * y;
     }

   double denominator = m_period * sum_x2 - sum_x * sum_x;
   double b = (m_period * sum_xy - sum_x * sum_y) / denominator;
   double a = (sum_y - b * sum_x) / m_period;

// 3. Calculate Deviation
   double deviation_offset = 0;
   if(m_channel_mode == DEVIATION_STANDARD)
     {
      double dev_sum_sq = 0;
      for(int k = 0; k < m_period; k++)
        {
         double y = m_price[start_prep + k];
         double reg_val = a + b * k;
         dev_sum_sq += MathPow(y - reg_val, 2);
        }
      deviation_offset = m_deviations * MathSqrt(dev_sum_sq / m_period);
     }
   else
     {
      double max_dev = 0;
      for(int k = 0; k < m_period; k++)
        {
         double y = m_price[start_prep + k];
         double reg_val = a + b * k;
         max_dev = MathMax(max_dev, MathAbs(y - reg_val));
        }
      deviation_offset = max_dev;
     }

// 4. Draw the Straight Line Segment
   for(int k = 0; k < m_period; k++)
     {
      int bar_index = start_prep + k;
      double reg_val = a + b * k;

      middle_buffer[bar_index] = reg_val;
      upper_buffer[bar_index]  = reg_val + deviation_offset;
      lower_buffer[bar_index]  = reg_val - deviation_offset;
     }
  }

//+------------------------------------------------------------------+
//| Method 3: Rolling Statistics (NEW)                               |
//+------------------------------------------------------------------+
void CLinearRegressionCalculator::CalculateState(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &out_slope[], double &out_r2[], double &out_forecast[])
  {
   if(rates_total < m_period)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   int loop_start = MathMax(m_period - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double sum_y = 0, sum_xy = 0, sum_y2 = 0;

      for(int k = 0; k < m_period; k++)
        {
         double price = m_price[i - m_period + 1 + k];
         double x = k; // Map x to 0..N-1

         sum_y += price;
         sum_xy += x * price;
         sum_y2 += price * price;
        }

      double b = 0;
      if(m_denom_x != 0)
         b = (m_period * sum_xy - m_sum_x * sum_y) / m_denom_x; // Slope

      double a = (sum_y - b * m_sum_x) / m_period; // Intercept
      double forecast = a + b * (m_period - 1);    // Current Value

      // R-Squared Calc
      // SST = Total Sum of Squares = Sum(y^2) - (Sum(y)^2)/N
      // SSR = Regression Sum of Squares = b * (Sum(xy) - Sum(x)Sum(y)/N)
      // R2 = SSR / SST

      // Alternative standard formula: R2 = (N*SumXY - SumX*SumY)^2 / (DenomX * DenomY)
      double denom_y = (m_period * sum_y2) - (sum_y * sum_y);
      double r2 = 0;

      if(m_denom_x > 0 && denom_y > 0)
        {
         double num = (m_period * sum_xy - m_sum_x * sum_y);
         r2 = (num * num) / (m_denom_x * denom_y);
        }

      out_slope[i]    = b;
      out_r2[i]       = r2;
      out_forecast[i] = forecast; // Same as 'middle_buffer' in Moving mode
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard)                                         |
//+------------------------------------------------------------------+
bool CLinearRegressionCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|             CLASS 2: CLinearRegressionCalculator_HA              |
//+==================================================================+
class CLinearRegressionCalculator_HA : public CLinearRegressionCalculator
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
bool CLinearRegressionCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
