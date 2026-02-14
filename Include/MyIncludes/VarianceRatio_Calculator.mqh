//+------------------------------------------------------------------+
//|                                     VarianceRatio_Calculator.mqh |
//|      Engine for Lo-MacKinlay Variance Ratio Test.                |
//|      VERSION 2.00: Integrated Price Preparation (Standard & HA). |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

//+==================================================================+
//|             CLASS: CVarianceRatioCalculator                      |
//+==================================================================+
class CVarianceRatioCalculator
  {
protected:
   int               m_window; // N
   int               m_lag;    // q

   //--- Persistent Buffers
   double            m_price[];     // Source price
   double            m_log_ret[];   // r1
   double            m_q_log_ret[]; // rq

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
   void              PrepareReturns(int rates_total, int start_index);

public:
                     CVarianceRatioCalculator() : m_window(64), m_lag(2) {};
   virtual          ~CVarianceRatioCalculator() {};

   bool              Init(int window, int lag);

   // Updated Calculate signature: Takes OHLC + PriceType
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &out_vr[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CVarianceRatioCalculator::Init(int window, int lag)
  {
   m_window = (window < 10) ? 10 : window;
   m_lag    = (lag < 2) ? 2 : lag;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CVarianceRatioCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &out_vr[])
  {
   if(rates_total < m_window + m_lag + 1)
      return;

// 1. Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_log_ret, rates_total);
      ArrayResize(m_q_log_ret, rates_total);
     }

   int start_calc = (prev_calculated > m_window + m_lag) ? prev_calculated - 1 : m_window + m_lag;
   int start_prep = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// 2. Prepare Price Series (Standard or HA)
   if(!PreparePriceSeries(rates_total, start_prep, price_type, open, high, low, close))
      return;

// 3. Prepare Log Returns based on m_price
   PrepareReturns(rates_total, start_prep);

// 4. Sliding Window Loop
   for(int i = start_calc; i < rates_total; i++)
     {
      double sum_1 = 0;
      double sum_sq_1 = 0;
      double sum_q = 0;
      double sum_sq_q = 0;

      for(int k = 0; k < m_window; k++)
        {
         int idx = i - k;
         double r1 = m_log_ret[idx];
         sum_1 += r1;
         sum_sq_1 += r1 * r1;

         double rq = m_q_log_ret[idx];
         sum_q += rq;
         sum_sq_q += rq * rq;
        }

      double var_1  = (sum_sq_1 - (sum_1 * sum_1) / m_window) / (m_window - 1);
      double var_q  = (sum_sq_q - (sum_q * sum_q) / m_window) / (m_window - 1);

      if(var_1 > 1.0e-12)
         out_vr[i] = var_q / (double)(m_lag * var_1);
      else
         out_vr[i] = 1.0;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price Series (Standard)                                  |
//+------------------------------------------------------------------+
bool CVarianceRatioCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//| Prepare Log Returns                                              |
//+------------------------------------------------------------------+
void CVarianceRatioCalculator::PrepareReturns(int rates_total, int start_index)
  {
   int start = (start_index < m_lag) ? m_lag : start_index;

   for(int i = start; i < rates_total; i++)
     {
      // 1-Period Log Return
      if(m_price[i-1] != 0)
         m_log_ret[i] = MathLog(m_price[i] / m_price[i-1]);
      else
         m_log_ret[i] = 0;

      // q-Period Log Return
      if(m_price[i-m_lag] != 0)
         m_q_log_ret[i] = MathLog(m_price[i] / m_price[i-m_lag]);
      else
         m_q_log_ret[i] = 0;
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
