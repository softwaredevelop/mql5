//+------------------------------------------------------------------+
//|                                   Autocorrelation_Calculator.mqh |
//|      Engine for Lag-1 Serial Correlation.                        |
//|      VERSION 2.00: Integrated Price Preparation.                 |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\MathStatistics_Calculator.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CAutocorrelationCalculator
  {
protected:
   int               m_period;
   CMathStatisticsCalculator m_stats;

   // Buffers
   double            m_price[];
   double            m_returns[];

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
   void              PrepareReturns(int rates_total, int start_index);

public:
                     CAutocorrelationCalculator() : m_period(20) {};
                    ~CAutocorrelationCalculator() {};

   bool              Init(int period);

   // Updated Signature
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &out_ac[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CAutocorrelationCalculator::Init(int period)
  {
   m_period = (period < 5) ? 5 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate                                                        |
//+------------------------------------------------------------------+
void CAutocorrelationCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &out_ac[])
  {
   if(rates_total < m_period + 2)
      return;

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_returns, rates_total);
     }

   int start_prep = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// 1. Prepare Price
   if(!PreparePriceSeries(rates_total, start_prep, price_type, open, high, low, close))
      return;

// 2. Prepare Returns
   PrepareReturns(rates_total, start_prep);

// 3. Rolling Correlation
   int start_calc = (prev_calculated > m_period) ? prev_calculated - 1 : m_period + 1;

   double vec_x[], vec_y[];
   ArrayResize(vec_x, m_period);
   ArrayResize(vec_y, m_period);

   for(int i = start_calc; i < rates_total; i++)
     {
      for(int k = 0; k < m_period; k++)
        {
         int idx = i - m_period + 1 + k;
         if(idx <= 0)
           {
            vec_x[k]=0;
            vec_y[k]=0;
            continue;
           }
         vec_x[k] = m_returns[idx];     // r(t)
         vec_y[k] = m_returns[idx - 1]; // r(t-1)
        }
      out_ac[i] = m_stats.CalculateCorrelation(vec_x, vec_y);
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price                                                    |
//+------------------------------------------------------------------+
bool CAutocorrelationCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i]=close[i];
            break;
         case PRICE_OPEN:
            m_price[i]=open[i];
            break;
         case PRICE_HIGH:
            m_price[i]=high[i];
            break;
         case PRICE_LOW:
            m_price[i]=low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i]=(high[i]+low[i])/2;
            break;
         case PRICE_TYPICAL:
            m_price[i]=(high[i]+low[i]+close[i])/3;
            break;
         case PRICE_WEIGHTED:
            m_price[i]=(high[i]+low[i]+2*close[i])/4;
            break;
         default:
            m_price[i]=close[i];
            break;
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Returns                                                  |
//+------------------------------------------------------------------+
void CAutocorrelationCalculator::PrepareReturns(int rates_total, int start_index)
  {
   int i = (start_index < 1) ? 1 : start_index;
   if(start_index == 0)
      m_returns[0] = 0.0;

   for(; i < rates_total; i++)
     {
      if(m_price[i-1] != 0)
         m_returns[i] = MathLog(m_price[i] / m_price[i-1]); // Log Return
      else
         m_returns[i] = 0.0;
     }
  }
//+------------------------------------------------------------------+
