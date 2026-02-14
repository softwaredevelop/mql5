//+------------------------------------------------------------------+
//|                                            FDI_Calculator.mqh    |
//|      Engine for Fractal Dimension Index (Carlos Sevcik Method).  |
//|      Measures curve complexity (1.0 = Line, 2.0 = Plane).        |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CFDICalculator
  {
protected:
   int               m_period;
   double            m_price[]; // Buffer for source prices

   // Pre-calculated constant for the formula denominator
   double            m_log_denominator;

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CFDICalculator(void) {};
   virtual          ~CFDICalculator(void) {};

   bool              Init(int period);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &out_fdi[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CFDICalculator::Init(int period)
  {
   m_period = (period < 10) ? 10 : period;

// Formula Denominator: Log( 2 * (N-1) )
// Note: Sevcik formula uses Natural Log (ln) or Log10? Standard implementation uses Log.
// As long as numerator uses same base, it matches. MQL MathLog is Natural Log (ln).
   m_log_denominator = MathLog(2.0 * (m_period - 1));

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Sevcik Method)                                 |
//+------------------------------------------------------------------+
void CFDICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &out_fdi[])
  {
   if(rates_total < m_period)
      return;

   int start_index = (prev_calculated > m_period) ? prev_calculated - 1 : m_period;

   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);
   if(!PreparePriceSeries(rates_total, (prev_calculated>0?prev_calculated-1:0), price_type, open, high, low, close))
      return;

// Main Loop
   for(int i = start_index; i < rates_total; i++)
     {
      // 1. Find Highest and Lowest in the window [i - Period + 1 ... i]
      double highest = -DBL_MAX;
      double lowest  = DBL_MAX;

      // Optimization: We could use ArrayMaximum if we managed a specific array subset,
      // but loop is fast enough for typical periods (30-100).
      for(int k=0; k<m_period; k++)
        {
         double p = m_price[i-k];
         if(p > highest)
            highest = p;
         if(p < lowest)
            lowest  = p;
        }

      double price_range = highest - lowest;

      // 2. Calculate Path Length (L)
      // L = Sum of Sqrt( dx^2 + dy^2 )
      // dx = 1 / (N-1)  (Normalized Time step)
      // dy = (Price[k] - Price[k-1]) / Range  (Normalized Price diff)

      double path_length = 0;
      double diff_x = 1.0 / (double)(m_period - 1); // Constant time step
      double diff_x_sq = diff_x * diff_x;

      if(price_range > 1.0e-9)
        {
         for(int k=1; k<m_period; k++) // Loop through N points implies N-1 segments
           {
            double diff_price = m_price[i - m_period + 1 + k] - m_price[i - m_period + 1 + k - 1]; // Forward diff in window
            double diff_y = diff_price / price_range;

            // Pythagorean theorem
            path_length += MathSqrt(diff_x_sq + (diff_y * diff_y));
           }
        }
      else
        {
         // Flat line = straight line
         path_length = 1.0;
        }

      // 3. Compute FDI
      // FDI = 1 + [ Log(L) + Log(2) ] / Log( 2*(N-1) )
      if(path_length > 0)
        {
         double fdi = 1.0 + (MathLog(path_length) + MathLog(2.0)) / m_log_denominator;
         out_fdi[i] = fdi;
        }
      else
        {
         out_fdi[i] = 1.0;
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price                                                    |
//+------------------------------------------------------------------+
bool CFDICalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//+------------------------------------------------------------------+
