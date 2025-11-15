//+------------------------------------------------------------------+
//|                   Polynomial_Regression_Object_Calculator.mqh    |
//|      Engine for drawing a Polynomial Regression Channel object.  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
class CPolynomialRegressionObjectCalculator
  {
protected:
   int               m_period;
   double            m_deviation;
   string            m_prefix;
   double            m_price[];
   int               m_last_rates_total;

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
   void              DrawChannelObjects(int rates_total, const datetime &time[]);

public:
                     CPolynomialRegressionObjectCalculator(void) : m_last_rates_total(0) {};
   virtual          ~CPolynomialRegressionObjectCalculator(void) {};

   bool              Init(int period, double deviation, string prefix);
   void              Calculate(int rates_total, const datetime &time[], ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CPolynomialRegressionObjectCalculator_HA : public CPolynomialRegressionObjectCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CPolynomialRegressionObjectCalculator::Init(int period, double deviation, string prefix)
  {
   m_period = (period < 3) ? 3 : period;
   m_deviation = (deviation <= 0) ? 2.0 : deviation;
   m_prefix = prefix;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CPolynomialRegressionObjectCalculator::Calculate(int rates_total, const datetime &time[], ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(rates_total <= m_last_rates_total && rates_total > 0)
      return;
   m_last_rates_total = rates_total;

   if(rates_total < m_period)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   DrawChannelObjects(rates_total, time);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CPolynomialRegressionObjectCalculator::DrawChannelObjects(int rates_total, const datetime &time[])
  {
   ObjectsDeleteAll(0, m_prefix);

   int start_index = rates_total - m_period;

   double sum_x=0, sum_y=0, sum_x2=0, sum_xy=0, sum_x3=0, sum_x4=0, sum_x2y=0;
   for(int j = 0; j < m_period; j++)
     {
      double x = j;
      double y = m_price[start_index + j];
      sum_x += x;
      sum_y += y;
      sum_x2 += x*x;
      sum_xy += x*y;
      sum_x3 += x*x*x;
      sum_x4 += x*x*x*x;
      sum_x2y += x*x*y;
     }

   double a=0, b=0, c=0;
   double n = m_period;
   double D = n * (sum_x2 * sum_x4 - sum_x3 * sum_x3) - sum_x * (sum_x * sum_x4 - sum_x2 * sum_x3) + sum_x2 * (sum_x * sum_x3 - sum_x2 * sum_x2);
   if(MathAbs(D) < 1e-10)
      return;
   a = (sum_y * (sum_x2 * sum_x4 - sum_x3 * sum_x3) - sum_xy * (sum_x * sum_x4 - sum_x2 * sum_x3) + sum_x2y * (sum_x * sum_x3 - sum_x2 * sum_x2)) / D;
   b = (n * (sum_xy * sum_x4 - sum_x2y * sum_x3) - sum_x * (sum_y * sum_x4 - sum_x2 * sum_x2y) + sum_x2 * (sum_y * sum_x3 - sum_x2 * sum_xy)) / D;
   c = (n * (sum_x2 * sum_x2y - sum_x3 * sum_xy) - sum_x * (sum_x * sum_x2y - sum_x2 * sum_xy) + sum_y * (sum_x * sum_x3 - sum_x2 * sum_x2)) / D;

   double sum_sq_err = 0;
   for(int j = 0; j < m_period; j++)
     {
      double x = j;
      double y = m_price[start_index + j];
      double y_fit = a + b * x + c * x * x;
      sum_sq_err += pow(y - y_fit, 2);
     }
   double std_dev = sqrt(sum_sq_err / n);

   datetime points_time[];
   double points_mid[], points_upper[], points_lower[];
   ArrayResize(points_time, m_period);
   ArrayResize(points_mid, m_period);
   ArrayResize(points_upper, m_period);
   ArrayResize(points_lower, m_period);

   for(int j = 0; j < m_period; j++)
     {
      points_time[j] = time[start_index + j];
      points_mid[j] = a + b * j + c * j * j;
      points_upper[j] = points_mid[j] + m_deviation * std_dev;
      points_lower[j] = points_mid[j] - m_deviation * std_dev;
     }

   for(int j = 0; j < m_period - 1; j++)
     {
      string mid_name = m_prefix + "_mid_" + (string)j;
      ObjectCreate(0, mid_name, OBJ_TREND, 0, points_time[j], points_mid[j], points_time[j+1], points_mid[j+1]);
      ObjectSetInteger(0, mid_name, OBJPROP_COLOR, clrCrimson);
      ObjectSetInteger(0, mid_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, mid_name, OBJPROP_SELECTABLE, false);

      string upper_name = m_prefix + "_upper_" + (string)j;
      ObjectCreate(0, upper_name, OBJ_TREND, 0, points_time[j], points_upper[j], points_time[j+1], points_upper[j+1]);
      ObjectSetInteger(0, upper_name, OBJPROP_COLOR, clrCrimson);
      ObjectSetInteger(0, upper_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, upper_name, OBJPROP_SELECTABLE, false);

      string lower_name = m_prefix + "_lower_" + (string)j;
      ObjectCreate(0, lower_name, OBJ_TREND, 0, points_time[j], points_lower[j], points_time[j+1], points_lower[j+1]);
      ObjectSetInteger(0, lower_name, OBJPROP_COLOR, clrCrimson);
      ObjectSetInteger(0, lower_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, lower_name, OBJPROP_SELECTABLE, false);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CPolynomialRegressionObjectCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
      if(ArrayResize(m_price, rates_total) != rates_total)
         return false;

   switch(price_type)
     {
      case PRICE_CLOSE:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
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
            m_price[i] = (high[i]+low[i]+close[i]+close[i])/4.0;
         break;
      default:
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CPolynomialRegressionObjectCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   if(ArraySize(m_price) != rates_total)
      if(ArrayResize(m_price, rates_total) != rates_total)
         return false;

   switch(price_type)
     {
      case PRICE_CLOSE:
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
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
            m_price[i] = (ha_high[i]+ha_low[i]+ha_close[i]+ha_close[i])/4.0;
         break;
      default:
         return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
