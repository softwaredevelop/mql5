//+------------------------------------------------------------------+
//|                   Polynomial_Regression_Slope_Calculator.mqh     |
//|      Engine for the Polynomial Regression Slope oscillator.      |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CPolynomialRegressionSlopeCalculator        |
//+==================================================================+
class CPolynomialRegressionSlopeCalculator
  {
protected:
   int               m_period;

   //--- Persistent Buffer for Incremental Calculation
   double            m_price[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CPolynomialRegressionSlopeCalculator(void) {};
   virtual          ~CPolynomialRegressionSlopeCalculator(void) {};

   bool              Init(int period);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &slope_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CPolynomialRegressionSlopeCalculator::Init(int period)
  {
   m_period = (period < 3) ? 3 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CPolynomialRegressionSlopeCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &slope_buffer[])
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

//--- 4. Calculate Polynomial Regression Slope (Incremental Loop)
   int loop_start = MathMax(m_period - 1, start_index);

// Pre-calculate X sums (constant for fixed period)
// Optimization: Calculate once in Init? No, period might change? No, Init sets period.
// But let's keep it local for simplicity, or move to Init for speed.
// For N=50, it's fast enough.

   double sum_x=0, sum_x2=0, sum_x3=0, sum_x4=0;
   for(int j = 0; j < m_period; j++)
     {
      double x = j;
      sum_x += x;
      sum_x2 += x*x;
      sum_x3 += x*x*x;
      sum_x4 += x*x*x*x;
     }

   double n = m_period;
   double D = n * (sum_x2 * sum_x4 - sum_x3 * sum_x3) - sum_x * (sum_x * sum_x4 - sum_x2 * sum_x3) + sum_x2 * (sum_x * sum_x3 - sum_x2 * sum_x2);

   if(MathAbs(D) < 1e-10)
      return; // Should not happen for N >= 3

   for(int i = loop_start; i < rates_total; i++)
     {
      double sum_y=0, sum_xy=0, sum_x2y=0;

      // Inner loop over the window [i - period + 1 ... i]
      for(int j = 0; j < m_period; j++)
        {
         double x = j;
         double y = m_price[i - m_period + 1 + j];
         sum_y += y;
         sum_xy += x*y;
         sum_x2y += x*x*y;
        }

      double Db = n * (sum_xy * sum_x4 - sum_x2y * sum_x3) - sum_x * (sum_y * sum_x4 - sum_x2 * sum_x2y) + sum_x2 * (sum_y * sum_x3 - sum_x2 * sum_xy);
      double Dc = n * (sum_x2 * sum_x2y - sum_x3 * sum_xy) - sum_x * (sum_x * sum_x2y - sum_x2 * sum_xy) + sum_y * (sum_x * sum_x3 - sum_x2 * sum_x2);

      double b = Db / D;
      double c = Dc / D;

      //--- Calculate the slope (1st derivative) at the current bar (x = n - 1)
      // y = a + bx + cx^2
      // y' = b + 2cx
      double x_current = n - 1;
      slope_buffer[i] = b + 2 * c * x_current;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CPolynomialRegressionSlopeCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|             CLASS 2: CPolynomialRegressionSlopeCalculator_HA     |
//+==================================================================+
class CPolynomialRegressionSlopeCalculator_HA : public CPolynomialRegressionSlopeCalculator
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
bool CPolynomialRegressionSlopeCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//+------------------------------------------------------------------+
