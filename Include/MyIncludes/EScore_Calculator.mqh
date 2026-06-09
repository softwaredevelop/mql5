//+------------------------------------------------------------------+
//|                                             EScore_Calculator.mqh|
//|      Engine for E-Score (Ehlers Smoother Z-Score).               |
//|      Strictly O(1) Incremental Optimized.                        |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"

#ifndef ESCORE_CALCULATOR_MQH
#define ESCORE_CALCULATOR_MQH

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>

//+==================================================================+
//|             CLASS: CEScoreCalculator                             |
//+==================================================================+
class CEScoreCalculator
  {
private:
   int                        m_period;
   ENUM_SMOOTHER_TYPE         m_type;
   bool                       m_use_ha;

   CEhlersSmootherCalculator *m_smoother_calc;
   CHeikinAshi_Calculator     m_ha_calc;

   double                     m_smooth_buf[];
   double                     m_price_buf[];

   double                     m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   bool              PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CEScoreCalculator();
                    ~CEScoreCalculator();

   bool              Init(int period, ENUM_SMOOTHER_TYPE type, bool use_ha);
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &out_escore[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEScoreCalculator::CEScoreCalculator() : m_period(20), m_type(SUPERSMOOTHER), m_use_ha(false), m_smoother_calc(NULL) {}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEScoreCalculator::~CEScoreCalculator()
  {
   if(CheckPointer(m_smoother_calc) == POINTER_DYNAMIC)
      delete m_smoother_calc;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CEScoreCalculator::Init(int period, ENUM_SMOOTHER_TYPE type, bool use_ha)
  {
   m_period = (period < 2) ? 2 : period;
   m_type = type;
   m_use_ha = use_ha;

   if(m_use_ha)
      m_smoother_calc = new CEhlersSmootherCalculator_HA();
   else
      m_smoother_calc = new CEhlersSmootherCalculator();

   if(CheckPointer(m_smoother_calc) == POINTER_INVALID)
      return false;

   return m_smoother_calc.Init(m_period, m_type, SOURCE_PRICE);
  }

//+------------------------------------------------------------------+
//| Calculate                                                        |
//+------------------------------------------------------------------+
void CEScoreCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                  const double &open[], const double &high[], const double &low[], const double &close[],
                                  double &out_escore[])
  {
   if(rates_total < m_period + 5)
      return;

   if(ArraySize(m_smooth_buf) != rates_total)
     {
      ArrayResize(m_smooth_buf, rates_total);
     }

// 1. Prepare aligned source prices (Standard or Heikin Ashi)
   if(!PreparePriceSeries(rates_total, prev_calculated, price_type, open, high, low, close))
      return;

// 2. Calculate underlying Ehlers Smoother
   m_smoother_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_smooth_buf);

// 3. Compute rolling Z-Score of the difference (m_price_buf - m_smooth_buf)
   int start = (prev_calculated > m_period) ? prev_calculated - 1 : m_period;

   for(int i = start; i < rates_total; i++)
     {
      double current_smooth = m_smooth_buf[i];
      double p = m_price_buf[i];

      if(current_smooth == 0.0 || current_smooth == EMPTY_VALUE)
         current_smooth = p;

      double sum_sq_diff = 0;
      for(int k = 0; k < m_period; k++)
        {
         int idx = i - k;
         double p_k = m_price_buf[idx];
         double s_k = m_smooth_buf[idx];

         if(s_k == 0.0 || s_k == EMPTY_VALUE)
            s_k = p_k;

         double diff = p_k - s_k;
         sum_sq_diff += diff * diff;
        }

      double std_dev = MathSqrt(sum_sq_diff / m_period);

      if(std_dev > 1.0e-9)
         out_escore[i] = (p - current_smooth) / std_dev;
      else
         out_escore[i] = 0.0;
     }
  }

//+------------------------------------------------------------------+
//| PreparePriceSeries                                               |
//+------------------------------------------------------------------+
bool CEScoreCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   int start = (start_index == 0) ? 0 : start_index;

   if(ArraySize(m_price_buf) != rates_total)
      ArrayResize(m_price_buf, rates_total);

   if(m_use_ha)
     {
      if(ArraySize(m_ha_open) != rates_total)
        {
         ArrayResize(m_ha_open, rates_total);
         ArrayResize(m_ha_high, rates_total);
         ArrayResize(m_ha_low, rates_total);
         ArrayResize(m_ha_close, rates_total);
        }
      m_ha_calc.Calculate(rates_total, start, open, high, low, close, m_ha_open, m_ha_high, m_ha_low, m_ha_close);

      for(int i = start; i < rates_total; i++)
        {
         switch(price_type)
           {
            case PRICE_CLOSE:
               m_price_buf[i] = m_ha_close[i];
               break;
            case PRICE_OPEN:
               m_price_buf[i] = m_ha_open[i];
               break;
            case PRICE_HIGH:
               m_price_buf[i] = m_ha_high[i];
               break;
            case PRICE_LOW:
               m_price_buf[i] = m_ha_low[i];
               break;
            case PRICE_MEDIAN:
               m_price_buf[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
               break;
            case PRICE_TYPICAL:
               m_price_buf[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
               break;
            case PRICE_WEIGHTED:
               m_price_buf[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) / 4.0;
               break;
            default:
               m_price_buf[i] = m_ha_close[i];
               break;
           }
        }
     }
   else
     {
      for(int i = start; i < rates_total; i++)
        {
         switch(price_type)
           {
            case PRICE_CLOSE:
               m_price_buf[i] = close[i];
               break;
            case PRICE_OPEN:
               m_price_buf[i] = open[i];
               break;
            case PRICE_HIGH:
               m_price_buf[i] = high[i];
               break;
            case PRICE_LOW:
               m_price_buf[i] = low[i];
               break;
            case PRICE_MEDIAN:
               m_price_buf[i] = (high[i] + low[i]) / 2.0;
               break;
            case PRICE_TYPICAL:
               m_price_buf[i] = (high[i] + low[i] + close[i]) / 3.0;
               break;
            case PRICE_WEIGHTED:
               m_price_buf[i] = (high[i] + low[i] + 2.0 * close[i]) / 4.0;
               break;
            default:
               m_price_buf[i] = close[i];
               break;
           }
        }
     }
   return true;
  }

#endif // ESCORE_CALCULATOR_MQH
//+------------------------------------------------------------------+
