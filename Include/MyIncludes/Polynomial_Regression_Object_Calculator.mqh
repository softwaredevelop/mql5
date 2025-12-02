//+------------------------------------------------------------------+
//|                   Polynomial_Regression_Object_Calculator.mqh    |
//|      VERSION 1.30: Restored full recalc logic for regression.    |
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
   color             m_mid_color, m_upper_color, m_lower_color;

   double            m_price[];
   int               m_last_rates_total;

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
   void              DrawChannelObjects(int rates_total, const datetime &time[]);

public:
                     CPolynomialRegressionObjectCalculator(void) : m_last_rates_total(0) {};
   virtual          ~CPolynomialRegressionObjectCalculator(void) {};

   bool              Init(int period, double deviation, string prefix, color mid_clr, color upper_clr, color lower_clr);

   //--- Reverted: No prev_calculated needed for regression
   void              Calculate(int rates_total, const datetime &time[], ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
  };

//+------------------------------------------------------------------+
bool CPolynomialRegressionObjectCalculator::Init(int period, double deviation, string prefix, color mid_clr, color upper_clr, color lower_clr)
  {
   m_period = (period < 3) ? 3 : period;
   m_deviation = (deviation <= 0) ? 2.0 : deviation;
   m_prefix = prefix;
   m_mid_color = mid_clr;
   m_upper_color = upper_clr;
   m_lower_color = lower_clr;
   return true;
  }

//+------------------------------------------------------------------+
void CPolynomialRegressionObjectCalculator::Calculate(int rates_total, const datetime &time[], ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Optimization: Only recalculate if rates_total changed (new bar) OR on every tick?
// Regression changes on every tick. So we must run.
// But we can skip if no new tick (handled by OnCalculate return).

   if(rates_total < m_period)
      return;

// Always prepare full series (fast copy)
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   DrawChannelObjects(rates_total, time);
  }

//+------------------------------------------------------------------+
void CPolynomialRegressionObjectCalculator::DrawChannelObjects(int rates_total, const datetime &time[])
  {
// We do NOT delete all objects here. We update them.

   int start_index = rates_total - m_period;

// --- Polynomial Regression Calculation ---
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

// --- Update Objects ---
   for(int j = 0; j < m_period - 1; j++)
     {
      double x1 = j;
      double x2 = j + 1;

      double y_mid1 = a + b * x1 + c * x1 * x1;
      double y_mid2 = a + b * x2 + c * x2 * x2;

      double y_up1 = y_mid1 + m_deviation * std_dev;
      double y_up2 = y_mid2 + m_deviation * std_dev;

      double y_dn1 = y_mid1 - m_deviation * std_dev;
      double y_dn2 = y_mid2 - m_deviation * std_dev;

      datetime t1 = time[start_index + j];
      datetime t2 = time[start_index + j + 1];

      // Midline
      string mid_name = m_prefix + "_mid_" + (string)j;
      if(ObjectFind(0, mid_name) < 0)
        {
         ObjectCreate(0, mid_name, OBJ_TREND, 0, t1, y_mid1, t2, y_mid2);
         ObjectSetInteger(0, mid_name, OBJPROP_COLOR, m_mid_color);
         ObjectSetInteger(0, mid_name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, mid_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, mid_name, OBJPROP_BACK, true);
         ObjectSetInteger(0, mid_name, OBJPROP_RAY, false);
        }
      else
        {
         ObjectMove(0, mid_name, 0, t1, y_mid1);
         ObjectMove(0, mid_name, 1, t2, y_mid2);
        }

      // Upper
      string upper_name = m_prefix + "_upper_" + (string)j;
      if(ObjectFind(0, upper_name) < 0)
        {
         ObjectCreate(0, upper_name, OBJ_TREND, 0, t1, y_up1, t2, y_up2);
         ObjectSetInteger(0, upper_name, OBJPROP_COLOR, m_upper_color);
         ObjectSetInteger(0, upper_name, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, upper_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, upper_name, OBJPROP_BACK, true);
         ObjectSetInteger(0, upper_name, OBJPROP_RAY, false);
        }
      else
        {
         ObjectMove(0, upper_name, 0, t1, y_up1);
         ObjectMove(0, upper_name, 1, t2, y_up2);
        }

      // Lower
      string lower_name = m_prefix + "_lower_" + (string)j;
      if(ObjectFind(0, lower_name) < 0)
        {
         ObjectCreate(0, lower_name, OBJ_TREND, 0, t1, y_dn1, t2, y_dn2);
         ObjectSetInteger(0, lower_name, OBJPROP_COLOR, m_lower_color);
         ObjectSetInteger(0, lower_name, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, lower_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, lower_name, OBJPROP_BACK, true);
         ObjectSetInteger(0, lower_name, OBJPROP_RAY, false);
        }
      else
        {
         ObjectMove(0, lower_name, 0, t1, y_dn1);
         ObjectMove(0, lower_name, 1, t2, y_dn2);
        }
     }

   ChartRedraw();
  }

//+------------------------------------------------------------------+
bool CPolynomialRegressionObjectCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);

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
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
     }
   return true;
  }

//+==================================================================+
class CPolynomialRegressionObjectCalculator_HA : public CPolynomialRegressionObjectCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CPolynomialRegressionObjectCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

//--- UPDATED: Pass 0 as start_index for full recalculation
   m_ha_calculator.Calculate(rates_total, 0, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);

   switch(price_type)
     {
      case PRICE_CLOSE:
         ArrayCopy(m_price, m_ha_close, 0, 0, rates_total);
         break;
      case PRICE_OPEN:
         ArrayCopy(m_price, m_ha_open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(m_price, m_ha_high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(m_price, m_ha_low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (m_ha_high[i]+m_ha_low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+m_ha_close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+2*m_ha_close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, m_ha_close, 0, 0, rates_total);
         break;
     }
   return true;
  }
//+------------------------------------------------------------------+
