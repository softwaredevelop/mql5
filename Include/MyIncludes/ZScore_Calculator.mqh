//+------------------------------------------------------------------+
//|                                          ZScore_Calculator.mqh   |
//|      Engine for Statistical Z-Score Calculation.                 |
//|      Standard Deviation distance from Moving Average.            |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|             CLASS: CZScoreCalculator                             |
//+==================================================================+
class CZScoreCalculator
  {
protected:
   int               m_period;

   //--- Engine for Mean (SMA)
   CMovingAverageCalculator *m_ma_calc;

   //--- Buffers
   double            m_price[];
   double            m_ma_buffer[];

   virtual bool      PreparePrice(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CZScoreCalculator();
   virtual          ~CZScoreCalculator();

   bool              Init(int period);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               double &out_z[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CZScoreCalculator::CZScoreCalculator() : m_ma_calc(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CZScoreCalculator::~CZScoreCalculator()
  {
   if(CheckPointer(m_ma_calc) == POINTER_DYNAMIC)
      delete m_ma_calc;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CZScoreCalculator::Init(int period)
  {
   m_period = (period < 2) ? 2 : period;

// Z-Score standard uses Simple Moving Average (SMA) for Mean
   m_ma_calc = new CMovingAverageCalculator();
   if(!m_ma_calc.Init(m_period, SMA))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CZScoreCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                  const double &open[], const double &high[],
                                  const double &low[], const double &close[],
                                  double &out_z[])
  {
   if(rates_total < m_period)
      return;

// 1. Resize Internal
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_ma_buffer, rates_total);
     }

// 2. Prepare Price Array
   if(!PreparePrice(rates_total, (prev_calculated>0 ? prev_calculated-1 : 0), price_type, open, high, low, close))
      return;

// 3. Calculate Mean (SMA)
// We run this on m_price array
   m_ma_calc.CalculateOnArray(rates_total, prev_calculated, m_price, m_ma_buffer);

// 4. Calculate Z-Score
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : m_period - 1;
   if(start_index < m_period - 1)
      start_index = m_period - 1;

   for(int i = start_index; i < rates_total; i++)
     {
      double sum_sq = 0;

      // Calculate Standard Deviation
      // StdDev = Sqrt( Sum( (Price - Mean)^2 ) / N )
      // Note: Using Population StdDev formula here (divide by N), typical in trading.
      // Mean for this window is m_ma_buffer[i]

      for(int k = 0; k < m_period; k++)
        {
         double diff = m_price[i - k] - m_ma_buffer[i];
         sum_sq += diff * diff;
        }

      double std_dev = MathSqrt(sum_sq / m_period);

      if(std_dev > 1.0e-9) // Anti-div-by-zero
         out_z[i] = (m_price[i] - m_ma_buffer[i]) / std_dev;
      else
         out_z[i] = 0.0;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Value                                                    |
//+------------------------------------------------------------------+
bool CZScoreCalculator::PreparePrice(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (high[i]+low[i])*0.5;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i]+low[i]+close[i]*2.0)*0.25;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
